CREATE PROCEDURE [dbo].[SP_PreprocessCasTbls] (@db_name varchar(50))
	AS
BEGIN
	DECLARE @sqlCommand NVARCHAR(4000)

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_Claim''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_Claim
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_VContract''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_VContract
            END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_IxvTotalTransactionExpenseByContract''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_IxvTotalTransactionExpenseByContract
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_IxvContract''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_IxvContract
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_VContact''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_VContact
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_IxvDeductibleOption''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_IxvDeductibleOption
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_IxvTotalExpenseByContract''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_IxvTotalExpenseByContract
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_IxvCouponRedemptionByContract''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_IxvCouponRedemptionByContract
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_VClaim''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_VClaim
            END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'IF (EXISTS (SELECT *
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = '''+@db_name+'''
             AND  TABLE_NAME = ''tbl_IxvContractCoupon''))
             BEGIN
                drop table  cas_snowflake_data_export.'+@db_name+'.tbl_IxvContractCoupon
             END'
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = 'SELECT  [contractID]
                      ,[claimID]
                      ,[repairFacilityID]
                      ,[contactName]
                      ,[contactID]
                      ,[repairOrderNumber]
                      ,[odometer]
                      ,[paymentMethodID]
                      ,[laborTotal]
                      ,[partsTotal]
                      ,[salesTax]
                      ,[deductible]
                      ,[grandTotal]
                      ,[authorizationNumber]
                      ,[authorizedAmount]
                      ,[lossTypeID]
                      ,[policeReportNumber]
                      ,[policeReportDate]
                      ,[insuranceSettlementAmount]
                      ,cast(null as varchar) as [claimComments]
                      ,[caseReserveAmount]
                      ,[datePaid]
                      ,[checkNumber]
                      ,[amountPaid]
                      ,[insurerID]
                      ,[policyNumber]
                      ,[bankID]
                      ,[loanNumber]
                      ,[payoffAmount]
                      ,[payoffDate]
                      ,[payeeID]
                      ,[statusID]
                      ,[lossDate]
                      ,[vscRefund]
                      ,[vehicleMarketValue]
                      ,[creditInsRefund]
                      ,[miscAdjustmentAmount]
                      ,[insuranceDeductible]
                      ,[authorizationDate]
                      ,[authorizationUser]
                      ,[creditCardID]
                      ,[dateCreated]
                      ,[dateApproved]
                      ,[isRemoteClaim]
                      ,[claimIsReceived]
                      ,[approveUser]
                      ,[claimReceivedDate]
                      ,[datePosted]
                      ,Null as timeStamp
                      ,[dateApprovedTime]
                      ,[internalClaimNumber]
                      ,[checkTrackingNumber]
                      ,[driverName]
                      ,[otherDriversInsurance]
                      ,[adjusterName]
                      ,[adjusterPhone]
                      ,[adjusterEmail]
                      ,[insuranceClaimNumber]
                      ,[lenderPayoffAddress]
                      ,[lenderPayoffCityStateZip]
                      ,[amountFinanced]
                      ,[loanStartDate]
                      ,[firstPaymentDate]
                      ,[monthlyPayment]
                      ,[numberOfPayments]
                      ,[interestRate]
                      ,[calculatedPayoff]
                      ,[amortizedPayoff]
                      ,[outstandingBalanceMax]
                      ,[insuranceValue]
                      ,[maintenanceRefund]
                      ,[titaniumRefund]
                      ,[outstandingBalanceUsedSummary]
                      ,[vehicleValueSummary]
                      ,[productRefundsSummary]
                      ,[excessDeductibleSummary]
                      ,[adminGoodwillAdjustmentSummary]
                      ,[endBalanceDate]
                      ,[endBalance]
                      ,[payoffDOL]
                      ,[claimForm]
                      ,[vscRefundNotes]
                      ,[maintenanceRefundNotes]
                      ,[titaniumRefundNotes]
                      ,[otherRefundNotes]
                      ,[authorizationForm]
                      ,[deniedReasonID]
                      ,[dateDenied]
                      ,[lenderPayoffAddressLine2]
                  INTO '+lower(QUOTENAME(@db_name))+'.tbl_Claim
                  FROM '+QUOTENAME(@db_name)+'.dbo.tblClaim';

    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' Select
                        v.inceptionDate,
                        v.bookedDate,
                        v.contractNumber,
                        v.termMonths,
                        v.termMiles,
                        v.deductibleAmount,
                        v.batchNumber,
                        v.customerName,
                        v.premiumTax,
                        v.cost,
                        v.FrontingFee,
                        v.TotalContractExpense,
                        v.dealershipName,
                        v.dealershipStateLongName,
                        v.insurerName,
                        v.bankName,
                        v.financedAmount,
                        v.loanTerm,
                        v.loanAPR,
                        v.vehicleMarketValue,
                        v.productCategoryDescription,
                        v.productDescription,
                        v.VehicleYear,
                        v.vehicleMakeDescription,
                        v.vehicleModelDescription,
                        v.vehicleDriveType,
                        v.vehicleFuelType,
                        v.vehicleTurboType,
                        v.vehicleType,
                        v.odometer,
                        v.inceptionMileage,
                        v.reserveMethodCode,
                        v.providerName,
                        v.contractID,
                        v.ContractCount,
                        v.ExpenseAmount,
                        v.BatchCloseDate,
                        v.cancellationRefundDate,
                        v.CancellationCount,
                        v.cancellationBatchNumber,
                        v.cancellationStoreRefundAmount,
                        v.percentageUsedInCancellation,
                        v.insurerID,
                        v.providerID
                    INTO '+lower(QUOTENAME(@db_name))+'.tbl_VContract
                    FROM '+QUOTENAME(@db_name)+'.dbo.v_Contracts v';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT  *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_IxvTotalTransactionExpenseByContract
                        FROM '+QUOTENAME(@db_name)+'.dbo.ixv_TotalTransactionExpenseByContract';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT  *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_VClaim
                        FROM '+QUOTENAME(@db_name)+'.dbo.v_Claims';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' Select *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_IxvContractCoupon
                        FROM '+QUOTENAME(@db_name)+'.dbo.ixv_ContractCoupons';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT  *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_VContact
                        FROM '+QUOTENAME(@db_name)+'.dbo.v_Contact';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT  *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_IxvDeductibleOption
                        FROM '+QUOTENAME(@db_name)+'.dbo.ixv_DeductibleOption';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT  *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_IxvTotalExpenseByContract
                        FROM '+QUOTENAME(@db_name)+'.dbo.ixv_TotalExpenseByContract';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT  *
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_IxvCouponRedemptionByContract
                        FROM '+QUOTENAME(@db_name)+'.dbo.ixv_CouponRedemptionByContract';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name

    SET @sqlCommand = ' SELECT
                             batchNumber
                            ,bookedDate
                            ,cancellationBatchID
                            ,CancellationCount
                            ,cancellationDate
                            ,cancellationfee
                            ,cancellationReasonID
                            ,cancellationRefundDate
                            ,cancellationStoreChargebackAmount
                            ,cancellationStoreRefundAmount
                            ,ContractCount
                            ,contractID
                            ,contractNumber
                            ,contractStatusCode
                            ,contractStatusDescription
                            ,cost
                            ,customerAddress
                            ,customerCity
                            ,customerDMSNumber
                            ,customerName
                            ,customerZipCode
                            ,dealershipCode
                            ,dealershipID
                            ,dealershipName
                            ,dealershipStateLongName
                            ,dealershipStateShortName
                            ,dealNumber
                            ,defaultClaimDeductible
                            ,expirationDate
                            ,expirationMileage
                            ,ForfeitedServicesAmount
                            ,inceptionDate
                            ,inceptionMileage
                            ,insurerName
                            ,odometer
                            ,percentageUsedInCancellation
                            ,premiumTax
                            ,price
                            ,productCategoryDescription
                            ,productDescription
                            ,ReserveMethodCode
                            ,reserveMethodDescription
                            ,TransferCount
                            ,transferredTo_contractID
                            ,vehicleMakeDescription
                            ,VehicleSold
                            ,VehicleYear
                            ,vin
                        INTO '+lower(QUOTENAME(@db_name))+'.tbl_IxvContract
                        FROM '+QUOTENAME(@db_name)+'.dbo.ixv_Contract';
    EXECUTE sp_executesql @sqlCommand, N'@db_name varchar(50)', @db_name = @db_name
END

