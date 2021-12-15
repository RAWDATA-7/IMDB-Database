  --// Lavet af: Anders Heide (66825), Frederik Jensen (66454), Jesper Petersen (66495), Simon Støvring(66424) //--


--// DATABASE SCRIPT //--

--// DROP PREVIOUSLY CREATED TABLES (IMDb) //--
DROP TABLE IF EXISTS titles CASCADE;
DROP TABLE IF EXISTS names CASCADE;
DROP TABLE IF EXISTS principals;
DROP TABLE IF EXISTS index;
DROP TABLE IF EXISTS akas;
DROP TABLE IF EXISTS knownfortitles;
DROP TABLE IF EXISTS professions;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS episodes;
DROP TABLE IF EXISTS ratings CASCADE;


--// DROP PREVIOUSLY CREATED TABLES (Framework) //--
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS searchhistory;
DROP TABLE IF EXISTS bookmarkings;
DROP TABLE IF EXISTS userratings;


--// CREATE NEW TABLES (IMDb) //--

--// Titles //--
CREATE TABLE IF NOT EXISTS titles(titleID varchar(10) PRIMARY KEY,
								 titleType varchar(20),
								 primaryTitle text,
								 originalTitle text,
								 isAdult bool,
								 startYear integer,
								 endYear integer,
								 runTimeMinutes integer,
								 poster varchar(256),
								 awards text,
								 plot text);

--// Names //--
CREATE TABLE IF NOT EXISTS names(nameID varchar(10) PRIMARY KEY,
								primaryName varchar(256),
								birthYear integer,
								deathYear integer,
								actorRating numeric(5,1));

--// Principals //--
CREATE TABLE IF NOT EXISTS principals(titleID varchar(10) REFERENCES titles(titleID),
								ordering integer,
								nameID varchar(10) REFERENCES names(nameID),
								category varchar(50),
								job text,
								characters text);

--// Index //--
CREATE TABLE IF NOT EXISTS index(titleID varchar(10) REFERENCES titles(titleID),
								word text,
								field varchar(1));

--// Akas //--
CREATE TABLE IF NOT EXISTS akas(titleID varchar(10) REFERENCES titles(titleID),
								ordering integer,
							   	title text,
								region varchar (10),
							   	language varchar (10),
							   	types varchar (256),
							   	attributes varchar(256),
							   	isOriginalTitle bool);

--// KnownForTitles //--
CREATE TABLE IF NOT EXISTS knownfortitles(titleID varchar(10),
								nameID varchar(10));
										 	
--// Profession //--
CREATE TABLE IF NOT EXISTS professions(professionName varchar(256),
								nameID varchar(10) REFERENCES names(nameID));
									  
--// Genres //--
CREATE TABLE IF NOT EXISTS genres(genreName varchar(256),
								titleID varchar(10) REFERENCES titles(titleID));
								
--// Ratings //--
CREATE TABLE IF NOT EXISTS ratings(titleID varchar(10) PRIMARY KEY REFERENCES titles(titleID),
								avgRating numeric(5,1),
								numVotes integer);

--// Episodes //--
CREATE TABLE IF NOT EXISTS episodes(episodeID varchar(10) PRIMARY KEY,
								parentID varchar(10) REFERENCES titles(titleID),
								seasonNumber integer,
								episodeNumber integer);


--// CREATE NEW TABLES (Framework) //--

--// Users //--
CREATE TABLE IF NOT EXISTS users(userID SERIAL PRIMARY KEY,
								 userName varchar(20),
								 firstName varchar(64),
								 lastName varchar(64),
								 email varchar(256),
								 sex varchar(1),
								 password varchar(512),
								 salt varchar(512));			 

--// SearchHistory //--
CREATE TABLE IF NOT EXISTS searchhistory(userID integer REFERENCES users(userID),
									 timeStamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
									 word varchar(256),
									 field varchar(1));

--// Bookmarkings //--
CREATE TABLE IF NOT EXISTS bookmarkings(userID integer REFERENCES users(userID),
								titleID varchar(10) REFERENCES titles(titleID));

--// UserRatings //--
CREATE TABLE IF NOT EXISTS userratings(userID integer REFERENCES users(userID),
									   titleID varchar(10) REFERENCES ratings(titleID), 
									   rating numeric(5,1));




--// INSERT AND UPDATE STATEMENTS //--

--// INSERT DATA INTO TABLE titles (new) FROM TABLE title_basics (old) //--

--//Fix data type for year columns in titles table//--
UPDATE title_basics SET startyear = null WHERE startyear = '    ';
UPDATE title_basics SET endyear = null WHERE endyear = '    ';
ALTER TABLE title_basics ALTER COLUMN startyear TYPE INTEGER USING startyear::integer;
ALTER TABLE title_basics ALTER COLUMN endyear TYPE INTEGER USING endyear::integer;

INSERT INTO titles SELECT DISTINCT * FROM title_basics;
UPDATE titles SET poster = NULL;
CREATE INDEX titles_titleID on titles(titleID);
CREATE INDEX omdb_data_tconst on omdb_data(tconst);
UPDATE titles SET poster = (SELECT DISTINCT poster FROM omdb_data WHERE omdb_data.tconst = titles.titleID);
UPDATE titles SET awards = (SELECT DISTINCT awards FROM omdb_data WHERE omdb_data.tconst = titles.titleID);
UPDATE titles SET plot = (SELECT DISTINCT plot FROM omdb_data WHERE omdb_data.tconst = titles.titleID);	
UPDATE titles SET poster = NULL WHERE poster = 'N/A';
UPDATE titles SET awards = NULL WHERE awards = 'N/A';
UPDATE titles SET plot = NULL WHERE plot = 'N/A';


--// INSERT DATA INTO TABLE akas (new) FROM TABLE title_akas (old) //--
INSERT INTO akas SELECT * FROM title_akas;


--// INSERT DATA INTO TABLE ratings (new) FROM TABLE title_ratings (old) //--
INSERT INTO ratings SELECT * FROM title_ratings;


--// INSERT DATA INTO TABLE index (new) FROM TABLE wi (old) //--
INSERT INTO index SELECT tconst, word, field FROM wi;


--// INSERT DATA INTO TABLE episodes (new) FROM TABLE title_episode (old) //--
INSERT INTO episodes SELECT DISTINCT * FROM title_episode;

--// INSERT DATA INTO TABLE names (new) FROM TABLE name_basics (old) //--
--//Fix data type for year columns in names table//--
UPDATE name_basics SET birthyear = null WHERE birthyear = '    ';
UPDATE name_basics SET deathyear = null WHERE deathyear = '    ';
ALTER TABLE name_basics ALTER COLUMN birthyear TYPE INTEGER USING birthyear::integer;
ALTER TABLE name_basics ALTER COLUMN deathyear TYPE INTEGER USING deathyear::integer;
INSERT INTO names SELECT nconst, primaryName, birthYear, deathYear FROM name_basics;

--// INSERT DATA INTO TABLE principals (new) FROM TABLE title_principals (old) //--
INSERT INTO principals SELECT * FROM title_principals WHERE nconst IN (SELECT nameID FROM names); 

--// UPADTES ACTOR RATING (D.7) //--
UPDATE names SET actorrating = rating.points
FROM
	(SELECT names.nameID, Sum(numvotes*avgrating)/sum(numvotes) points 
	FROM principals NATURAL LEFT JOIN ratings 
	NATURAL LEFT JOIN names
	GROUP BY names.nameID) as rating
WHERE names.nameID = rating.nameID;


--// INSERT DATA INTO TABLE knownfortitles (new) FROM TABLE name_basics (old) //--
--// The DO-block splits data from single cells across multiple rows //--
DO $$
DECLARE
	title varchar(10);
	rec record;
BEGIN
	FOR rec IN SELECT nconst, knownForTitles FROM name_basics
	LOOP
		FOREACH title IN ARRAY
			(regexp_split_to_array(rec.knownForTitles, ','))
		LOOP
			INSERT INTO knownfortitles(nameID, titleID) VALUES(rec.nconst, title);
		END LOOP;
	END LOOP;
END $$;


--// INSERT DATA INTO TABLE professions (new) FROM TABLE name_basics (old) //--
--// The DO-block splits data from single cells across multiple rows //--
DO $$
DECLARE
	profession varchar(256);
	rec record;
BEGIN
	FOR rec IN SELECT nconst, primaryprofession FROM name_basics
	LOOP
		FOREACH profession IN ARRAY
			(regexp_split_to_array(rec.primaryprofession, ','))
		LOOP
			INSERT INTO professions(nameID, professionName) VALUES(rec.nconst, profession);
		END LOOP;
	END LOOP;
END $$;


--// INSERT DATA INTO TABLE knownfortitles (new) FROM TABLE name_basics (old) //--
--// The DO-block splits data from single cells across multiple rows //-- 
DO $$
DECLARE
	genre varchar(256);
	rec record;
BEGIN
	FOR rec IN SELECT tconst, genres FROM title_basics
	LOOP
		FOREACH genre IN ARRAY
			(regexp_split_to_array(rec.genres, ','))
		LOOP
			INSERT INTO genres(titleID, genreName) VALUES(rec.tconst, genre);
		END LOOP;
	END LOOP;
END $$;




--// FRAMEWORK FUNCTIONALITY //--


--// Import extension for hashing passwords
--CREATE EXTENSION pgcrypto;

--// Create User functionality //--
CREATE OR REPLACE PROCEDURE createUser(userName varchar(20),
					firstName varchar(64),
					lastName varchar(64),
					email varchar(256),
					sex varchar(1),
					password bytea,
					salt bytea)
	LANGUAGE plpgsql
	AS $$ 
		BEGIN
			INSERT INTO users(userName, firstName, lastName, email, sex, password, salt) 
			VALUES (userName, firstName, lastName, email, sex, password, salt);
		END; 
	$$;


CREATE OR REPLACE PROCEDURE bookmarking(userID int, 
					titleID varchar(10))
	LANGUAGE plpgsql
	AS $$
		BEGIN
			INSERT INTO bookmarkings(userID, titleID)
			VALUES(userID, titleID);
		END;	
	$$;


--// UPDATE RATING //--
--// Procedure for updating title ratings and for storing individual user ratings //--
--// Works by checking whether a user previously rated a title or not //--
--// 	If no:	User can give a title rating and a new average title rating is calculated //--
--//	If yes:	User can change the previous rating and a new average title rating is calculated //--
--// Title average ratings are calculated in a separate function
CREATE OR REPLACE PROCEDURE updateUserRating(uID int, 
											 tID varchar(10), 
											 r numeric(5,1))
LANGUAGE plpgsql
	AS $$
		DECLARE
			increase bool = FALSE;
			oldVote integer;
				BEGIN
					IF NOT EXISTS (SELECT userID, titleID FROM userratings WHERE uID = userratings.userID AND tID = userratings.titleID ) THEN
						INSERT INTO userratings(userID, titleID, rating) VALUES(uID, tID, r);
						increase = TRUE;
					ELSE
						oldVote = (SELECT rating FROM userratings WHERE uID = userratings.userID AND tID = userratings.titleID);
						UPDATE userratings SET rating = r WHERE uID = userratings.userID AND tID = userratings.titleID;
						increase = FALSE;
					END IF;
				PERFORM updateTitleRating(tID, r, increase, oldVote);
				PERFORM actor_rating(tID);
				END;
$$;


--// UPDATETITLERATING //--
--// Function for calculating either a new average rating for a title or a 'changed' average rating for a title //--
CREATE OR REPLACE FUNCTION updateTitleRating(t varchar(10),
											r numeric(5,1),
											increase bool,
											oldVote int) 
RETURNS void 
	AS $$
	BEGIN
		IF (increase IS TRUE) then
					UPDATE ratings SET avgRating = (numVotes * avgRating + r)/(numVotes+1),	
										numVotes = numVotes + 1;
			ELSE
					UPDATE ratings SET avgRating = ((numVotes * avgRating - oldVote + r)/(numVotes));
					END IF;
			END;
	$$
LANGUAGE plpgsql;


--// UPDATE SEARCHHISTORY //--
--// Procedure for inserting a search string into a users search history table //--
--// Works by saving a search strings userID, and timestamp into a temporary table //--
--// The search string is handled by a function that splits it up into individual words //--
--// The individual words then gets inserted into the users search history table as individual rows with userID and timestamp //--
CREATE OR REPLACE PROCEDURE updateSearchHistory(userID integer, 
						searchResult text,
						f varchar(1),
						t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
									
LANGUAGE plpgsql
	AS $$	
		BEGIN
			CREATE TABLE tempsearchtable(userID integer, 
							searchResult text, 
							f varchar(1), 
							t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);					 
			INSERT INTO tempSearchTable(userID, searchResult, f, t) 
			VALUES(userID, searchResult, f, t);
		PERFORM splitSearchResult();
		END;
	$$;


--// SPLITSEARCHSTRING //--
--// Function for splitting up the words in a users search text into individual rows and saving these into the users 'searchhistory' table //--
CREATE OR REPLACE FUNCTION splitSearchResult() 
RETURNS void 
AS $$ 
	DECLARE word varchar (256); 
			rec record;
		BEGIN
			FOR rec IN SELECT userID, searchResult, f, t FROM tempsearchtable
				LOOP
					FOREACH word IN ARRAY
						(regexp_split_to_array(rec.searchResult, ' '))
					LOOP
						INSERT INTO searchhistory(userID, word, field, timeStamp) VALUES(rec.userID, word, rec.f, rec.t);
					END LOOP;
				END LOOP;
			DROP TABLE IF EXISTS tempsearchtable;
		END;
$$
LANGUAGE plpgsql;


--// SIMPLE SEARCH //--
--// Function that returns a table with title ID's and title names, where a users searchstring exist in title name or plot //--
--// This function also updates the users searchhistory-table //-- 
CREATE OR REPLACE FUNCTION string_search(u integer, s text, f varchar(1), TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE(titleID varchar(10), title text)
AS $$
	CALL updateSearchHistory(u, s, f, CURRENT_TIMESTAMP);
	(SELECT titleID, primaryTitle FROM titles WHERE primaryTitle ILIKE CONCAT('%',s,'%')
	UNION ALL 
	 SELECT titleID, primaryTitle FROM titles WHERE  plot ILIKE CONCAT('%',s,'%'));
$$
LANGUAGE sql;


--// STRUCTURED STRING SEARCH (Movies) //--
--// for searching out titles //--
--// Function joins the main tables and takes 4 search parameters - (hardcoded to: title, plot, character, name) //--
--// Returns table with IDs and Titles where the passed parameters are found in the respective fields (title, plot, character, name) //--
--// This function also updates the users searchhistory-table //-- 
CREATE OR REPLACE FUNCTION structured_string_search(u integer, s1 text, s2 text, s3 text, s4 text, f varchar(1), TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE(titleID varchar(10), title text)
AS $$
	CALL updateSearchHistory(u, CONCAT(s1,' ', s2, ' ', s3, ' ', s4), f, CURRENT_TIMESTAMP);
	SELECT titles.titleID, titles.primaryTitle
	FROM titles NATURAL LEFT JOIN principals
	NATURAL LEFT JOIN names
	WHERE primaryTitle ILIKE CONCAT('%',s1,'%') 
		AND primaryName ILIKE CONCAT('%',s4,'%') 
		AND characters ILIKE CONCAT('%',s3,'%') 
		AND plot ILIKE CONCAT('%',s2,'%');
$$
LANGUAGE sql;


--// STRUCTURED STRING SEARCH (Actors) //--
--// For searching out actors //--
--// Function joins the main tables and takes 4 search parameters - (hardcoded to: title, plot, character, name) //--
--// Returns table with IDs and Names where the passed parameters are found in the respective fields (title, plot, character, name) //--
--// This function also updates the users searchhistory-table //-- 
CREATE OR REPLACE FUNCTION structured_string_search_actors(u integer, s1 text, s2 text, s3 text, s4 text, f varchar(1), TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE(nameID varchar(10), name text)
AS $$
	CALL updateSearchHistory(u, CONCAT(s1,' ', s2, ' ', s3, ' ', s4), f, CURRENT_TIMESTAMP);
	SELECT principals.nameID, names.primaryName
	FROM titles NATURAL LEFT JOIN principals
	NATURAL LEFT JOIN names
	WHERE primaryTitle ILIKE CONCAT('%',s1,'%') 
		AND primaryName ILIKE CONCAT('%',s4,'%') 
		AND characters ILIKE CONCAT('%',s3,'%') 
		AND plot ILIKE CONCAT('%',s2,'%');
$$
LANGUAGE sql;


--// RELATED ACTORS //--
--// Finds other actors that have worked on movies with the actor that was searched for //--
--// Returns a list of other actors in an order of high -> low co-acting frequency //--
--// This function also updates the users searchhistory-table //-- 
CREATE OR REPLACE FUNCTION find_related_actor(u integer, actorName varchar(256) ,f varchar(1), TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE(nameID varchar(10), name text, freq bigint)
AS $$
CALL updateSearchHistory(u,actorName,f,CURRENT_TIMESTAMP);
SELECT p.nameID, n.primaryName, count(*) freq
FROM principals p NATURAL LEFT JOIN names n
WHERE titleID IN (SELECT titleID 
			FROM titles t NATURAL LEFT JOIN principals p 
			NATURAL LEFT JOIN names n 
			WHERE primaryName ILIKE CONCAT('%',actorName,'%'))
GROUP BY p.nameID, n.primaryName
ORDER BY count(*) DESC
OFFSET 1;
$$
LANGUAGE sql;

--// ACTORRATING //--
--// Updates actor rating for the given nameID //--
--// Adding titleID as input to reduce runtime of updateUserRating(); //--
CREATE OR REPLACE FUNCTION actor_rating(inputTitleID varchar(10))
RETURNS VOID
AS $$
	UPDATE names SET actorrating = rating.points
	FROM
	(SELECT names.nameID, Sum(numvotes*avgrating)/sum(numvotes) points 
	FROM principals NATURAL LEFT JOIN ratings 
			NATURAL LEFT JOIN names
	GROUP BY names.nameID) as rating
	WHERE names.nameID = rating.nameID AND names.nameID IN (SELECT nameID FROM principals WHERE titleID = inputTitleID);
$$
LANGUAGE sql;


--// POPULARACTORS //--
--// Lists actors ordered by a descending total avg-rating for a given title //--
CREATE OR REPLACE FUNCTION popular_actors(titleName varchar (256))
RETURNS TABLE(actorName varchar(256), rating numeric(5,1), role varchar(256))
AS $$
	SELECT primaryName, actorrating, category AS role 
	FROM principals NATURAL LEFT JOIN names 
			NATURAL LEFT JOIN titles
	WHERE primaryTitle ILIKE CONCAT('%',titleName,'%') ORDER BY actorrating DESC  
$$
LANGUAGE sql;

CREATE OR REPLACE FUNCTION popular_title_actors(tid varchar (10))
RETURNS TABLE(actorName varchar(256), actorid varchar(10))
AS $$
	SELECT primaryName, nameid 
	FROM principals NATURAL LEFT JOIN names 
			NATURAL LEFT JOIN titles
	WHERE principals.titleid = tid ORDER BY actorrating DESC  
$$
LANGUAGE sql;


--//POPULAR TITLE//--
--Pull with the 10 best rated movies related to an actor
--nm0586568
CREATE OR REPLACE FUNCTION popular_titles(nId varchar(10))
RETURNS TABLE(titleID varchar(10), primarytitle varchar(10), avgRating numeric(5,1))
AS $$
SELECT titles.titleID, titles.primaryTitle, ratings.avgRating
FROM principals 
NATURAL LEFT JOIN titles
NATURAL LEFT JOIN ratings
WHERE principals.nameid = nId
ORDER BY ratings.avgrating DESC 
LIMIT 10;
$$
LANGUAGE sql;


--// SIMILAR MOVIES //--
--// Returns titleIDs and primaryTitles for the top 5 most matching titles //--
--// functions works by checking other titles attached genres //--
--// Function then counts the number of equal genres attached to the other titles //--
--// Titles with most equal genres are listed first in the result set //--
--// This function also updates the users searchhistory-table //-- 
CREATE OR REPLACE FUNCTION similar_movie(userID int, searchTitle varchar(10), field varchar(1), t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE (titleID varchar(10), titleName varchar(256), rank BIGINT)
AS $$
	CALL updatesearchhistory(userID, searchTitle, field, t);
	SELECT titles.titleID, primarytitle, count(g.genrename) as rank 
	FROM titles NATURAL LEFT JOIN genres g, 
		(SELECT titleID, genrename FROM genres WHERE titleID = searchTitle) AS genres 
	WHERE g.genrename = genres.genrename AND titletype ILIKE '%movie%' AND titles.titleID != searchTitle 
	GROUP BY titles.titleID, primarytitle 
	ORDER BY rank DESC LIMIT 5
$$
LANGUAGE sql;


--// BEST RATED MOVIE //--
--Pull with the 100 best rated movies
CREATE OR REPLACE FUNCTION best_rated_titles()
RETURNS TABLE(image varchar(512),titleID varchar(10), titleName varchar(256), avgRating numeric(5,1))
AS $$
	SELECT titles.poster, titles.titleid, titles.primarytitle, ratings.avgrating 
	FROM ratings 
	LEFT JOIN titles
	ON titles.titleid = ratings.titleid
	WHERE ratings.numVotes > 100000 AND titletype != 'tvEpisode'
	ORDER BY ratings.avgrating DESC
	LIMIT 10000;
$$
LANGUAGE sql;

--// BEST_RATED_ACTOR //--
-- Pull with the 100 best rated actors
CREATE OR REPLACE FUNCTION best_rated_actors()
RETURNS TABLE(nameid varchar(10), actorName varchar(256), bYear int, dYear int, rating numeric(5,1))
AS $$
	SELECT principals.nameid, names.primaryname, names.birthyear, names.deathyear, names.actorrating 
	FROM principals 
	NATURAL LEFT JOIN ratings
	NATURAL LEFT JOIN names
	WHERE principals.category = 'actor' OR principals.category = 'actress'
	GROUP BY principals.nameid, names.primaryname, names.actorrating, names.birthyear, names.deathyear
	HAVING sum(ratings.numvotes) > 50000
	ORDER BY names.actorrating DESC
	LIMIT 10000;
$$
LANGUAGE sql;

SELECT * FROM NAMES NATURAL LEFT JOIN professions WHERE nameid = 'nm0095144'


--// EXACTMATCH //--
--// Shows only movies where all search parameters are match //--
--// This function also updates the users searchhistory-table //-- 
CREATE OR REPLACE FUNCTION exact_match(u int, s1 text, s2 text, s3 text, f varchar(1), TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE(titleID varchar(10), titleName varchar(256))
AS $$
	CALL updateSearchHistory(u, CONCAT(s1,' ', s2, ' ', s3), f, CURRENT_TIMESTAMP);
	SELECT titles.titleID, primaryTitle 
	FROM titles,
			(SELECT titleID FROM index WHERE word = s1
					INTERSECT
			 SELECT titleID FROM index WHERE word = s2
					INTERSECT
			 SELECT titleID FROM index WHERE word = s3) AS words
	WHERE titles.titleid = words.titleID;
$$
LANGUAGE sql;

CREATE OR REPLACE FUNCTION find_co_actors(aId varchar(10))
RETURNS TABLE(nameID varchar(10))
AS $$
SELECT p.nameID
FROM principals p NATURAL LEFT JOIN names n
WHERE titleID IN (SELECT titleID 
			FROM titles t NATURAL LEFT JOIN principals p 
			NATURAL LEFT JOIN names n 
			WHERE n.nameid = aId)
GROUP BY p.nameID, n.primaryName
ORDER BY count(*) DESC
OFFSET 1;
$$
LANGUAGE sql;

--// BESTMATCH //--
--// Combination of procedure and functions //--
--// Input:	In theory an INFINITE number of search words //--
--// Output: 	Table of search result with titleID, primaryTitle and rank //--
--// The RANK column shows how many of the search words are found for the titles in the respective rows //--
--// Works by: SELECTing the give_best_match function //--
--// This function (give_best_match) calls a procedure which creates 2 tempTables and inserts searchtext, userID etc into one of the tables //--
--// From the procedure (best_match) another function (best_match_output) is performed //..
--// This function (best_match_output) takes the search text from a temptable and splits it up into individual words //--
--// The individual words are then saved in the remaining temptable //--
--// The ResultSet are then made back in the function (give_best_match) from the tempTable with individual words //--
--// This function also updates the users searchhistory-table //-- 
CREATE TABLE IF NOT EXISTS tempsearchtablebestmatch(u integer, searchResult text, f varchar(1), t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS temptableforbmoutput(titleID varchar(10), rank bigint, titleName varchar(256));


--// BEST_MATCH (Procedure) //--
CREATE OR REPLACE PROCEDURE best_match(u integer, searchResult text, f varchar (1), t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
LANGUAGE plpgsql
	AS $$	
		BEGIN
			DELETE FROM tempsearchtablebestmatch;
			DELETE FROM temptableforBMoutput;
			CREATE TABLE IF NOT EXISTS tempsearchtablebestmatch(u integer, 
										searchResult text, 
										f varchar(1), 
										t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);					 
			INSERT INTO tempsearchtablebestmatch(u, searchResult, f, t) 
				VALUES(u, searchResult, f, t);
			CREATE TABLE IF NOT EXISTS temptableforbmoutput(titleID varchar(10), rank bigint, titleName varchar(256));
			PERFORM best_match_output();
		END;
	$$;


--// FINDING THE BEST_MATCH //--
CREATE OR REPLACE FUNCTION best_match_output()									
RETURNS void
AS $$
	DECLARE searchword varchar(256); 
			rec record;
		BEGIN
			FOR rec IN SELECT tempsearchtablebestmatch.searchResult FROM tempsearchtablebestmatch
				LOOP
					FOREACH searchword IN ARRAY
						(regexp_split_to_array(rec.searchResult, ' '))
					LOOP
						INSERT INTO temptableforBMoutput 
						(SELECT titles.titleID, 1 relevance, primarytitle FROM titles, 
						(SELECT index.titleID FROM index WHERE word = searchword) AS magnus WHERE titles.titleid = magnus.titleID);
					END LOOP;
				END LOOP;
				
		END
$$
LANGUAGE plpgsql;

--// RETURNING THE BEST_MATCH //--
CREATE OR REPLACE FUNCTION give_best_match(u int, searchResult text, f varchar(1), t TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)
RETURNS TABLE(titleID varchar(10), rank numeric(5,1), titleName varchar(256))
AS $$
	CALL best_match(u, searchResult, f, t);
	CALL updatesearchhistory(u, searchResult, f, t);
	SELECT titleID, sum(rank) rank, titleName FROM temptableforbmoutput GROUP BY titleID, titleName ORDER BY sum(rank) DESC;
$$
LANGUAGE sql;




--// KEYWORDSWEIGHTED //--
--// Shows the most relevant keywords for all titles in database //--
--SELECT word, (count(*)/100) FROM index WHERE field = 'p' OR field = 't' GROUP BY word ORDER BY count(*) DESC




--// ADD CONSTRAINT TO knownfortitles //--
--// Can be run to add keys to knownfortitles, but is not needed for now //--
CREATE INDEX knownfortitles_titleID ON knownfortitles(titleID);
CREATE INDEX knownfortitles_nameID ON knownfortitles(nameID);
DELETE FROM knownfortitles WHERE titleID NOT IN (SELECT titleID FROM titles);
ALTER TABLE knownfortitles ADD CONSTRAINT knownfortitles_nameid_fkey  FOREIGN KEY (nameID) REFERENCES names(nameID);
ALTER TABLE knownfortitles ADD CONSTRAINT knownfortitles_titleid_fkey FOREIGN KEY (titleID) REFERENCES titles(titleID);


ALTER TABLE bookmarkings ADD CONSTRAINT bookmarkings_userID_titleID_pkey  PRIMARY KEY (userID, titleID);

--// TESTS FOR FUNCTIONS AND PROCEDURES //--
--________________________________________--
CALL createUser('ByornGold69K', 'Bjørn', 'Guldager', 'x@factor.dk', 'y', 'proManxFactor');
CALL createUser('TestGodX', 'Test', 'icles', 'admin@jesnen.dk', 'm', 'test1234');
CALL bookmarking('15','tt0167261');
CALL updateUserRating('15', 'tt0295407', 10);
CALL updateUserRating('2', 'tt0295407', 4);
CALL updateUserRating('2', 'tt0295407', 9);
CALL updateUserRating('2', 'tt0295407', 8);
CALL updateSearchHistory('1', 'Det her er hvad jeg søger på', 'a', CURRENT_TIMESTAMP);
SELECT * FROM string_search('1', 'two towers', 'a', CURRENT_TIMESTAMP);
SELECT * FROM structured_string_search('1','', 'james', '', 'Daniel Craig', 'a', CURRENT_TIMESTAMP);
SELECT * FROM structured_string_search_actors('1', 'Towers', 'Frodo', '', 'Elijah', 'a', CURRENT_TIMESTAMP);
SELECT * FROM find_related_actor('1', 'Mads Mikkelsen', 'a', CURRENT_TIMESTAMP);
SELECT * FROM popular_actors('Two Towers');
SELECT * FROM similar_movie('6', '', 'a', CURRENT_TIMESTAMP);
SELECT * FROM exact_match('6','apple','mads','mikkelsen','a',CURRENT_TIMESTAMP);
SELECT * FROM give_best_match('6', 'casino craig james mads bond daniel craig', 'a',CURRENT_TIMESTAMP);
SELECT * FROM give_best_match('1', 'elijah wood', 'a',CURRENT_TIMESTAMP);
SELECT * FROM give_best_match('1', 'tom cruise fallout mission', 'a',CURRENT_TIMESTAMP);
--SELECT * FROM best_rated_movies();
SELECT * FROM best_rated_titles();
SELECT * FROM best_rated_actors();
SELECT * FROM popular_titles('nm0185819');
SELECT * FROM popular_titles('nm0095144');
SELECT * FROM find_co_actors('nm0095144');
SELECT * FROM popular_title_actors('tt0381061');

SELECT * from professions where nameid ='nm0185819'
SELECT * FROM names where nameid = 'nm0185819'
--DELETE FROM searchhistory;
--DELETE FROM bookmarkings;
--DELETE FROM userratings;
--DELETE FROM users;

--// DROP ORIGINAL TABLES //--
DROP TABLE IF EXISTS title_basics;
DROP TABLE IF EXISTS title_crew;
DROP TABLE IF EXISTS title_akas;
DROP TABLE IF EXISTS title_ratings;
DROP TABLE IF EXISTS title_principals;
DROP TABLE IF EXISTS title_episode;
DROP TABLE IF EXISTS name_basics;
DROP TABLE IF EXISTS omdb_data;
DROP TABLE IF EXISTS wi;
