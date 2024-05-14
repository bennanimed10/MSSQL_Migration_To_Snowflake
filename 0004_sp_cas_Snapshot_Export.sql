CREATE PROCEDURE [dbo].[SP_CasSnapshotExport]
    (
         @SQLServerName varchar(100)
        ,@Account_Storage varchar(100)
        ,@db_name varchar(50)
        ,@token varchar(400)
	)
AS
BEGIN

    EXECUTE sp_configure 'show advanced options', 1
            RECONFIGURE;

    EXECUTE sp_configure 'xp_cmdshell', 1
            RECONFIGURE

    DECLARE @rmdircmd nvarchar(280);
    DECLARE @char_timestap VARCHAR(20)
    DECLARE @rmdatasqlstmt  VARCHAR(4000)
    DECLARE @tblName VARCHAR(100)
    DECLARE @tblDestName VARCHAR(100)
    DECLARE @cmd VARCHAR(4000)
    DECLARE @cmdcompress VARCHAR(4000)

    SET @db_Name = LOWER(@db_Name)

    EXECUTE SP_PreprocessCasTbls @db_name

    /*
        backup the current data the DB in CAS_Snowflake_Data folder
    */
    IF OBJECT_ID('tempdb..#tbl_ToExportSqlStatment') IS NOT NULL
    DROP TABLE #tbl_ToExportSqlStatment
    SELECT distinct ' '''
        + 'bcp'
        + ' ' + [database_name] +'.'+ coalesce([schema_name], @db_Name) +'.'+ table_name
        + ' out '
        +'D:\CAS_Snowflake_Data\'+ @db_Name+ '\' + table_dest_name + '.csv'
        + ' -c -t "^|^" '
        + ' -T -S ' + @SQLServerName + ''
        + '''' as sqlstmt,
        'D:\CAS_Snowflake_Data\'+ @db_Name+ '\' as folderpath,
        @db_Name as dbname,
        table_name as table_name,
        table_dest_name as table_dest_name
    INTO #tbl_ToExportSqlStatment
    FROM tbl_CASReportTableExport
    WHERE [database_name] IN ('cas_snowflake_data_export', @db_name)


    DECLARE @sqlstmt  VARCHAR(4000)
    DECLARE @folderpath VARCHAR(4000)

    DECLARE db_cursorsqlstmt CURSOR FOR
    SELECT
         sqlstmt
        ,folderpath
        ,table_name
        ,table_dest_name
    FROM #tbl_ToExportSqlStatment

    OPEN db_cursorsqlstmt
    FETCH NEXT
    FROM db_cursorsqlstmt
    INTO @sqlstmt,@folderpath,@tblname,@tblDestName

    SET @rmdircmd = N'RMDIR ' + @folderpath + ' /S /Q'
        print (@rmdircmd)
        EXECUTE master.dbo.xp_cmdshell @rmdircmd, no_output
        WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sqlstmt = replace(@sqlstmt,'''','')

        EXECUTE MASTER.dbo.xp_create_subdir @folderpath
        EXECUTE MASTER.dbo.xp_cmdshell @sqlstmt

        SET @cmdcompress = '""C:\Program Files\7-Zip\7z.exe" a "D:\CAS_Snowflake_Data\' + @db_Name + '\' + @tblDestName + '.csv.gz'
                + '" "D:\CAS_Snowflake_Data\' + @db_Name + '\' + @tblDestName + '.csv""'
        EXECUTE master.dbo.xp_cmdshell @cmdcompress

     FETCH NEXT FROM db_cursorsqlstmt INTO @sqlstmt,@folderpath,@tblname,@tblDestName
    END

    CLOSE db_cursorsqlstmt DEALLOCATE db_cursorsqlstmt

    /*
        upload the most recent data into azure container
    */
    SET @char_timestap =  (select max(convert(varchar, snapshot_dt,111) + '/'+ replace(convert(varchar, snapshot_dt,8),':','/')) as snapshot_path from tbl_BatchTimeStamp where database_name = @db_name)
    print @char_timestap

    DECLARE @URL nvarchar(2000)
    SET @URL = 'https://' + @Account_Storage +'.blob.core.windows.net/'

    SET  @cmd = '""C:/Program Files/azcopy/azcopy.exe"  cp "D:\CAS_Snowflake_Data\' + @db_Name + '\*.csv.gz" "'  + @URL + lower(replace(@db_Name,'_','-'))+ '-dsp-landing' + '/' +@char_timestap + '/' + @token + '"" '
    EXEC MASTER..XP_CMDSHELL @cmd

END

