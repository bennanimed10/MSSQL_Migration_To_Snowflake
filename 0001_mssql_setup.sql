DROP DATABASE IF EXISTS [cas_snowflake_data_export];
CREATE DATABASE [cas_snowflake_data_export]
GO

USE cas_snowflake_data_export
GO

CREATE TABLE tbl_CASReportTableExport
(
    database_name   NVARCHAR(100),
    Schema_name     NVARCHAR(100),
    table_name      NVARCHAR(100),
    table_dest_name NVARCHAR(100)
)
GO

CREATE SCHEMA casv2_dealersocket
    GO
CREATE SCHEMA casv2_kornerstone
    GO
CREATE SCHEMA casv2_other
    GO
CREATE SCHEMA casv2_permaplate
	GO

DECLARE @schema_name NVARCHAR(3)
SET @schema_name = 'dbo'

IF OBJECT_ID('tempdb..#tbl_CasDbs') IS NOT NULL
    DROP TABLE #tbl_CasDbs
IF OBJECT_ID('tempdb..#tbl_Cas') IS NOT NULL
    DROP TABLE #tbl_Cas

CREATE TABLE #tbl_CasDbs
(
    data_base_name NVARCHAR(50)
)
CREATE TABLE #tbl_Cas
(
    table_name NVARCHAR(50),
    dest_file_name NVARCHAR(50),
)

INSERT INTO #tbl_CasDbs VALUES ('CASV2_DealerSocket')
INSERT INTO #tbl_CasDbs VALUES ('CASV2_Kornerstone')
INSERT INTO #tbl_CasDbs VALUES ('CASV2_Other')
INSERT INTO #tbl_CasDbs VALUES ('CASV2_PermaPlate')

INSERT INTO #tbl_Cas VALUES ('tblBank','tbl_Bank')
INSERT INTO #tbl_Cas VALUES ('tblBatch','tbl_Batch')
INSERT INTO #tbl_Cas VALUES ('tblBatchStatus','tbl_BatchStatus')
INSERT INTO #tbl_Cas VALUES ('tblCompany','tbl_Company')
INSERT INTO #tbl_Cas VALUES ('tblContact','tbl_Contact')
INSERT INTO #tbl_Cas VALUES ('tblContract','tbl_Contract')
INSERT INTO #tbl_Cas VALUES ('tblContract_TransactionExpenses','tbl_ContractTransactionExpense')
INSERT INTO #tbl_Cas VALUES ('tblContract_xref_tblDealershipProductExpense','tbl_ContractXrefDealershipProductExpense')
INSERT INTO #tbl_Cas VALUES ('tblContract_xref_tblProductOptionGroupItem','tbl_ContractXrefProductOptionGroupItem')
INSERT INTO #tbl_Cas VALUES ('tblContractCouponRedemption','tbl_ContractCouponRedemption')
INSERT INTO #tbl_Cas VALUES ('tblContractCouponRedemptionDetail','tbl_ContractCouponRedemptionDetail')
INSERT INTO #tbl_Cas VALUES ('tblContractCoupons','tbl_ContractCoupon')
INSERT INTO #tbl_Cas VALUES ('tblCouponRemittanceBatch','tbl_CouponRemittanceBatch')
INSERT INTO #tbl_Cas VALUES ('tblCustomer','tbl_Customer')
INSERT INTO #tbl_Cas VALUES ('tblDealership','tbl_Dealership')
INSERT INTO #tbl_Cas VALUES ('tblDealership_xref_dnnUsers','tbl_DealershipXrefDnnUser')
INSERT INTO #tbl_Cas VALUES ('tblDealershipProduct','tbl_DealershipProduct')
INSERT INTO #tbl_Cas VALUES ('tblDealershipProductCoupon','tbl_DealershipProductCoupon')
INSERT INTO #tbl_Cas VALUES ('tblEmployee','tbl_Employee')
INSERT INTO #tbl_Cas VALUES ('tblExpenseTypes','tbl_ExpenseType')
INSERT INTO #tbl_Cas VALUES ('tblGroupDealerships','tbl_GroupDealership')
INSERT INTO #tbl_Cas VALUES ('tblGroupUsers','tbl_GroupUser')
INSERT INTO #tbl_Cas VALUES ('tblInsurer','tbl_Insurer')
INSERT INTO #tbl_Cas VALUES ('tblProduct','tbl_Product')
INSERT INTO #tbl_Cas VALUES ('tblProductCategory','tbl_ProductCategory')
INSERT INTO #tbl_Cas VALUES ('tblProductOptionGroupItem','tbl_ProductOptionGroupItem')
INSERT INTO #tbl_Cas VALUES ('tblProductOptions','tbl_ProductOption')
INSERT INTO #tbl_Cas VALUES ('tblProductRateGroup','tbl_ProductRateGroup')
INSERT INTO #tbl_Cas VALUES ('tblProductRateGroupItem','tbl_ProductRateGroupItem')
INSERT INTO #tbl_Cas VALUES ('tblProductState','tbl_ProductState')
INSERT INTO #tbl_Cas VALUES ('tblProvider','tbl_Provider')
INSERT INTO #tbl_Cas VALUES ('tblReserveMethod','tbl_ReserveMethod')
INSERT INTO #tbl_Cas VALUES ('tblState','tbl_State')
INSERT INTO #tbl_Cas VALUES ('tblValues','tbl_Value')
INSERT INTO #tbl_Cas VALUES ('tblVehicleMakes','tbl_VehicleMake')
INSERT INTO #tbl_Cas VALUES ('tblVehicleMakes_xref_tblVehicleTypes','tbl_VehicleMakeXrefVehicleType')
INSERT INTO #tbl_Cas VALUES ('tblVehicleModels','tbl_VehicleModel')
INSERT INTO #tbl_Cas VALUES ('tblVehicles','tbl_Vehicle')
INSERT INTO #tbl_Cas VALUES ('tblVehicleTypes','tbl_VehicleType')

DECLARE @db_name  NVARCHAR(50)
DECLARE @tbl_name  NVARCHAR(50)
DECLARE @dest_file_name NVARCHAR(50)
DECLARE @sqlstmt NVARCHAR(200)
DECLARE db_cursorsqlstmt CURSOR FOR
SELECT
	 data_base_name
    ,Table_name
	,dest_file_name
FROM #tbl_Cas
         CROSS JOIN #tbl_CasDbs OPEN db_cursorsqlstmt
FETCH NEXT
FROM db_cursorsqlstmt
INTO @db_name , @tbl_name , @dest_file_name
    WHILE @@FETCH_STATUS = 0
BEGIN

    SET
    @sqlstmt = 'INSERT INTO tbl_CASReportTableExport VALUES (''' + @db_name + ''',''' + @schema_name + ''',''' + @tbl_name +''',''' + @dest_file_name +''')';
    EXECUTE sp_executesql @sqlstmt, N'@db_name NVARCHAR(50) ,@schema_name NVARCHAR(3) ,@tbl_name NVARCHAR(50) , @dest_file_name NVARCHAR(50)',@db_name,@schema_name ,@tbl_name, @dest_file_name

    FETCH NEXT FROM db_cursorsqlstmt INTO @db_name , @tbl_name , @dest_file_name

END
CLOSE db_cursorsqlstmt DEALLOCATE db_cursorsqlstmt

INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_Claim','tbl_Claim')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_VClaim','tbl_VClaim')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_IxvContract','tbl_IxvContract')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_IxvDeductibleOption','tbl_IxvDeductibleOption')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_IxvTotalExpenseByContract','tbl_IxvTotalExpenseByContract')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_IxvTotalTransactionExpenseByContract','tbl_IxvTotalTransactionExpenseByContract')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_VContact','tbl_VContact')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_VContract','tbl_VContract')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_IxvContractCoupon','tbl_IxvContractCoupon')
INSERT INTO tbl_CASReportTableExport VALUES ('cas_snowflake_data_export',NULL,'tbl_IxvCouponRedemptionByContract','tbl_IxvCouponRedemptionByContract')

GO

CREATE TABLE tbl_Config
(
    config_name NVARCHAR(20),
    config_val  NVARCHAR(400)
)

INSERT INTO tbl_Config VALUES ('StorageAccountName' , 'cassnowflakesadev')
INSERT INTO tbl_Config VALUES ('TokenID' , '?sv=2017-07-29&ss=bqtf&srt=sco&sp=rwdlacup&se=2041-12-01&st=2021-12-01&spr=https&sig=1%2BYjoZjI6qmLJm1guu3T0WFasnvI7s%2BrqWPNDReR2%2FI%3D')
INSERT INTO tbl_Config VALUES ('SQLServerName' , 'kornerstone-dnn')

GO

CREATE TABLE tbl_BatchTimestamp
(
    row_id        int identity(1,1) primary key clustered,
    database_name NVARCHAR(50),
    snapshot_dt   datetime,
)
CREATE NONCLUSTERED INDEX IDX_snapshot_dt ON dbo.tbl_BatchTimestamp(snapshot_dt)

GO
