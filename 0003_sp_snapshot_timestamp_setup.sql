CREATE PROCEDURE [dbo].[SP_SnapshotTimestampSetup](@db_name varchar(50))
AS
BEGIN
	DECLARE @current_timestamp DATETIME
	
	DECLARE @rowcount INTEGER

	INSERT INTO tbl_BatchTimestamp
			values (@db_name,getdate())
END