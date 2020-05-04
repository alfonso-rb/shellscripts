/* 
Approved security updates compliance report 
Find computers within a specific target group that need security updates 
that have been approved to this group (or a parent group) for at least N days 
Optionally, only consider updates of a given MSRC severity rating 
*/ 
 
USE SUSDB 
SET NOCOUNT ON 
DECLARE @TargetGroup nvarchar(30) 
DECLARE @Days int 
 
-- Configure these values as needed 
--SELECT @TargetGroup = 'Unassigned Computers' 
SELECT @TargetGroup = 'All Computers' 
SELECT @Days = 7 
 
-- Find the target group and all it's parent groups 
DECLARE @groups AS TABLE (Id uniqueidentifier NOT NULL) 
DECLARE @groupId uniqueidentifier 
SET @groupId = ( 
    SELECT ComputerTargetGroupId 
    FROM PUBLIC_VIEWS.vComputerTargetGroup 
    WHERE vComputerTargetGroup.Name = @TargetGroup 
) 
IF @groupId is NULL 
    RAISERROR ('Invalid Target Group Name', 16, 1) 
WHILE @groupId IS NOT NULL 
BEGIN 
    INSERT INTO @groups SELECT @groupId 
    SET @groupId = ( 
        SELECT ParentTargetGroupId 
        FROM PUBLIC_VIEWS.vComputerTargetGroup 
        WHERE vComputerTargetGroup.ComputerTargetGroupId = @groupId 
    ) 
END 
 
-- Find all security updates which have been approved for install for at least 
-- @Days to the specified target group (or one of it's parent groups) 
DECLARE @updates AS TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY) 
INSERT INTO @updates 
SELECT vUpdate.UpdateId 
FROM 
    PUBLIC_VIEWS.vUpdate 
    INNER JOIN PUBLIC_VIEWS.vUpdateApproval on vUpdateApproval.UpdateId = vUpdate.UpdateId 
WHERE 
    DATEDIFF (day, vUpdateApproval.CreationDate, GETUTCDATE()) > @Days 
    AND vUpdate.MsrcSeverity is NOT NULL 
    AND vUpdateApproval.Action = 'Install' 
    AND vUpdateApproval.ComputerTargetGroupId IN (SELECT * FROM @groups) 
    -- Can just take updates with important/critical MSRC ratings by using this clause instead: 
    -- AND vUpdate.MsrcSeverity in (’Critical’, ’Important’) 
    -- Other values for MsrcSeverity include Moderate, Low, and Unspecified 
 
-- List of computers not in compliance for at least one updates 
SELECT vComputerTarget.Name as 'Computer Name', COUNT(*) AS 'Missing Updates' 
FROM PUBLIC_VIEWS.vComputerGroupMembership 
    INNER JOIN PUBLIC_VIEWS.vComputerTarget on vComputerGroupMembership.ComputerTargetId = vComputerTarget.ComputerTargetId 
    INNER JOIN PUBLIC_VIEWS.vComputerTargetGroup on vComputerGroupMembership.ComputerTargetGroupId = vComputerTargetGroup.ComputerTargetGroupId 
    INNER JOIN PUBLIC_VIEWS.vUpdateInstallationInfoBasic on vUpdateInstallationInfoBasic.ComputerTargetId = vComputerTarget.ComputerTargetId 
    INNER JOIN @updates GROUPS on vUpdateInstallationInfoBasic.UpdateId = GROUPS.Id 
WHERE vComputerTarget.ComputerTargetId = vUpdateInstallationInfoBasic.ComputerTargetId 
    AND vUpdateInstallationInfoBasic.State in (2, 3, 5, 6) 
    -- 2 = Needed, 2 = Failed, 5 =  
    AND vComputerTargetGroup.Name = @TargetGroup 
GROUP BY vComputerTarget.Name 
ORDER BY 'Missing Updates' DESC 
 
 
-- List of updates not in compliance for at least one computer 
;WITH UpdateCounts AS ( 
SELECT vUpdate.UpdateId, COUNT(*) AS NumComputers 
FROM PUBLIC_VIEWS.vComputerGroupMembership 
    INNER JOIN PUBLIC_VIEWS.vComputerTarget on vComputerGroupMembership.ComputerTargetId = vComputerTarget.ComputerTargetId 
    INNER JOIN PUBLIC_VIEWS.vComputerTargetGroup on vComputerGroupMembership.ComputerTargetGroupId = vComputerTargetGroup.ComputerTargetGroupId 
    INNER JOIN PUBLIC_VIEWS.vUpdateInstallationInfoBasic on vComputerTarget.ComputerTargetId = vUpdateInstallationInfoBasic.ComputerTargetId 
    INNER JOIN PUBLIC_VIEWS.vUpdate on vUpdate.UpdateId = vUpdateInstallationInfoBasic.UpdateId 
    INNER JOIN @updates GROUPS on vUpdate.UpdateId = GROUPS.Id 
WHERE 
    vComputerTargetGroup.Name = @TargetGroup 
    AND vUpdateInstallationInfoBasic.UpdateId = GROUPS.Id 
    AND vUpdateInstallationInfoBasic.State in (2, 3, 5, 6) 
GROUP BY vUpdate.UpdateId) 
SELECT vUpdate.DefaultTitle as 'Update Title', UpdateCounts.UpdateId as 'Update ID', UpdateCounts.NumComputers as 'Number computers' 
FROM PUBLIC_VIEWS.vUpdate 
    INNER JOIN UpdateCounts on vUpdate.UpdateId = UpdateCounts.UpdateId 
ORDER BY 'Number computers' DESC 