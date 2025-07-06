# 📊 KQL Queries for M365 Audit Log Analysis

*Author: Bilel Azaiez*

## 🚀 Quick Start Queries

### Collection Health Check
```kql
// Verify data collection is working
M365AuditCollectionSummary_CL
| where TimeGenerated > ago(24h)
| project TimeGenerated, TotalRecords_d, Success_b, DurationSeconds_d, ErrorCount_d
| order by TimeGenerated desc
```

### Data Overview by Service
```kql
// See which M365 services are generating data
search "M365*_CL"
| where TimeGenerated > ago(24h)
| summarize EventCount = count() by Type
| where Type !contains "Summary" and Type !contains "Error"
| order by EventCount desc
```

## 🔍 Security Analysis Queries

### Suspicious Sign-in Activity
```kql
// Failed sign-ins from unusual locations
M365AzureADAudit_CL
| where TimeGenerated > ago(7d)
| where Operation_s =~ "UserLoginFailed"
| where isnotempty(ClientIP_s)
| summarize FailedAttempts = count() by UserId_s, UserDisplayName_s, ClientIP_s, bin(TimeGenerated, 1h)
| where FailedAttempts > 5
| order by FailedAttempts desc
```

### Admin Activity Monitoring
```kql
// Administrative actions across all M365 services
union M365*_CL
| where TimeGenerated > ago(24h)
| where Operation_s contains "Admin" or Operation_s contains "Set" or Operation_s contains "New" or Operation_s contains "Remove"
| where UserType_s =~ "Admin" or UserType_s =~ "DcAdmin"
| project TimeGenerated, Type, Operation_s, UserId_s, UserDisplayName_s, UserDepartment_s
| order by TimeGenerated desc
```

### Data Loss Prevention (DLP) Events
```kql
// DLP policy violations and actions taken
M365DLP*_CL
| where TimeGenerated > ago(7d)
| summarize PolicyViolations = count() by PolicyName_s, Severity_s, bin(TimeGenerated, 1d)
| order by TimeGenerated desc, PolicyViolations desc
```

## 📧 Exchange Analysis

### Mailbox Access Patterns
```kql
// Who's accessing mailboxes and how
M365ExchangeAudit_CL
| where TimeGenerated > ago(7d)
| where Operation_s in ("MailboxLogin", "FolderBind", "MessageBind")
| summarize AccessCount = count() by UserId_s, UserDisplayName_s, Operation_s, ClientInfoString_s
| order by AccessCount desc
```

### Email Forwarding Rules
```kql
// Potentially suspicious email forwarding rules
M365ExchangeAudit_CL
| where TimeGenerated > ago(30d)
| where Operation_s contains "Forward" or Operation_s contains "Rule"
| project TimeGenerated, UserId_s, UserDisplayName_s, Operation_s, Parameters_s
| order by TimeGenerated desc
```

### Large Email Attachments
```kql
// Monitor large attachments (potential data exfiltration)
M365ExchangeAudit_CL
| where TimeGenerated > ago(7d)
| where Operation_s =~ "Send"
| where isnotempty(Parameters_s)
| where Parameters_s contains "Size"
| project TimeGenerated, UserId_s, UserDisplayName_s, Parameters_s, ClientIP_s
| order by TimeGenerated desc
```

## 📁 SharePoint & OneDrive Analysis

### File Sharing Activity
```kql
// External file sharing events
M365SharePointAudit_CL
| where TimeGenerated > ago(7d)
| where Operation_s contains "Share" or Operation_s contains "Anonymous"
| project TimeGenerated, UserId_s, UserDisplayName_s, Operation_s, ObjectId_s, ClientIP_s
| order by TimeGenerated desc
```

### Large File Downloads
```kql
// Monitor large file downloads
M365SharePointAudit_CL
| where TimeGenerated > ago(24h)
| where Operation_s =~ "FileDownloaded"
| extend FileName = extract(@"([^/]+)$", 1, ObjectId_s)
| project TimeGenerated, UserId_s, UserDisplayName_s, FileName, ObjectId_s, ClientIP_s
| order by TimeGenerated desc
```

### Sensitivity Label Usage
```kql
// Files with sensitivity labels applied
M365SharePointAudit_CL
| where TimeGenerated > ago(7d)
| where isnotempty(SensitivityLabelId_g)
| join kind=leftouter (
    M365SensitivityLabels_CL
    | project Id_g, DisplayName_s
) on $left.SensitivityLabelId_g == $right.Id_g
| project TimeGenerated, UserId_s, UserDisplayName_s, ObjectId_s, LabelName = DisplayName_s
| order by TimeGenerated desc
```

## 👥 Teams Analysis

### Meeting and Call Activity
```kql
// Teams meeting participation
M365TeamsAudit_CL
| where TimeGenerated > ago(7d)
| where Operation_s contains "Meeting" or Operation_s contains "Call"
| summarize MeetingCount = count() by UserId_s, UserDisplayName_s, bin(TimeGenerated, 1d)
| order by TimeGenerated desc, MeetingCount desc
```

### External Guest Access
```kql
// External users joining Teams meetings
M365TeamsAudit_CL
| where TimeGenerated > ago(7d)
| where UserType_s =~ "Guest" or UserId_s contains "#EXT#"
| project TimeGenerated, UserId_s, UserDisplayName_s, Operation_s, ObjectId_s
| order by TimeGenerated desc
```

## 🎯 User Behavior Analysis

### Most Active Users
```kql
// Users with highest activity across all services
union M365*_CL
| where TimeGenerated > ago(7d)
| where isnotempty(UserId_s)
| where Type !contains "Summary" and Type !contains "Error" and Type !contains "Labels"
| summarize ActivityCount = count() by UserId_s, UserDisplayName_s, UserDepartment_s
| order by ActivityCount desc
| take 50
```

### After Hours Activity
```kql
// Activity outside business hours (6 PM - 6 AM)
union M365*_CL
| where TimeGenerated > ago(7d)
| extend Hour = hourofday(TimeGenerated)
| where Hour >= 18 or Hour <= 6
| where Type !contains "Summary" and Type !contains "Error"
| summarize AfterHoursActivity = count() by UserId_s, UserDisplayName_s, bin(TimeGenerated, 1d)
| order by TimeGenerated desc, AfterHoursActivity desc
```

### Geographic Analysis
```kql
// User activity by location
union M365*_CL
| where TimeGenerated > ago(7d)
| where isnotempty(ClientIP_s)
| summarize ActivityCount = count() by UserId_s, UserDisplayName_s, ClientIP_s
| order by ActivityCount desc
```

## 📈 Compliance & Reporting

### Data Retention Compliance
```kql
// Files approaching retention policy limits
M365SharePointAudit_CL
| where TimeGenerated > ago(30d)
| where Operation_s contains "Retention" or Operation_s contains "Delete"
| project TimeGenerated, UserId_s, Operation_s, ObjectId_s
| order by TimeGenerated desc
```

### Audit Log Coverage
```kql
// Verify all expected services are logging
search "M365*_CL"
| where TimeGenerated > ago(24h)
| summarize LastSeen = max(TimeGenerated), EventCount = count() by Type
| order by LastSeen desc
```

### User Enrichment Quality
```kql
// Check data enrichment completeness
union M365*_CL
| where TimeGenerated > ago(24h)
| where Type !contains "Summary" and Type !contains "Error" and Type !contains "Labels"
| summarize 
    TotalEvents = count(),
    EnrichedEvents = countif(isnotempty(UserDisplayName_s)),
    DepartmentEnriched = countif(isnotempty(UserDepartment_s)),
    ManagerEnriched = countif(isnotempty(UserManager_s))
| extend 
    EnrichmentRate = round((EnrichedEvents * 100.0) / TotalEvents, 2),
    DepartmentRate = round((DepartmentEnriched * 100.0) / TotalEvents, 2),
    ManagerRate = round((ManagerEnriched * 100.0) / TotalEvents, 2)
```

## 🚨 Security Monitoring Alerts

### Bulk Operations Detection
```kql
// Detect bulk file operations (potential data exfiltration)
M365SharePointAudit_CL
| where TimeGenerated > ago(1h)
| where Operation_s in ("FileDownloaded", "FileCopied", "FileDeleted")
| summarize OperationCount = count() by UserId_s, UserDisplayName_s, Operation_s, bin(TimeGenerated, 5m)
| where OperationCount > 20
| order by TimeGenerated desc, OperationCount desc
```

### Privileged Access Monitoring
```kql
// Monitor privileged role assignments and usage
M365AzureADAudit_CL
| where TimeGenerated > ago(24h)
| where Operation_s contains "Role" and (Operation_s contains "Add" or Operation_s contains "Assign")
| project TimeGenerated, UserId_s, UserDisplayName_s, Operation_s, Target_s, ModifiedProperties_s
| order by TimeGenerated desc
```

### Anomalous Login Patterns
```kql
// Users logging in from unusual number of locations
M365AzureADAudit_CL
| where TimeGenerated > ago(7d)
| where Operation_s =~ "UserLoggedIn"
| summarize LocationCount = dcount(ClientIP_s) by UserId_s, UserDisplayName_s
| where LocationCount > 5
| order by LocationCount desc
```

## 💡 Performance & Optimization

### Collection Performance
```kql
// Monitor collection efficiency
M365AuditCollectionSummary_CL
| where TimeGenerated > ago(7d)
| summarize 
    AvgDuration = avg(DurationSeconds_d),
    MaxDuration = max(DurationSeconds_d),
    AvgRecords = avg(TotalRecords_d),
    SuccessRate = avg(toint(Success_b)) * 100
| extend 
    AvgDurationMin = round(AvgDuration / 60, 2),
    MaxDurationMin = round(MaxDuration / 60, 2)
```

### Data Volume Trends
```kql
// Track data volume trends over time
search "M365*_CL"
| where TimeGenerated > ago(30d)
| where Type !contains "Summary" and Type !contains "Error"
| summarize EventCount = count() by Type, bin(TimeGenerated, 1d)
| order by TimeGenerated desc, EventCount desc
```

### Error Analysis
```kql
// Analyze collection errors
M365AuditCollectionErrors_CL
| where TimeGenerated > ago(7d)
| summarize ErrorCount = count() by ErrorMessage_s
| order by ErrorCount desc
```

## 🔧 Custom Queries

### Template for Custom Analysis
```kql
// Template - modify as needed
union M365*_CL
| where TimeGenerated > ago(1d)
| where Type == "M365ExchangeAudit_CL"  // Change service type
| where Operation_s == "YourOperation"   // Change operation
| where UserId_s == "user@domain.com"    // Filter by user
| project TimeGenerated, UserId_s, UserDisplayName_s, Operation_s, ObjectId_s
| order by TimeGenerated desc
```

### Building Complex Queries
```kql
// Multi-service correlation example
let TimeRange = ago(24h);
let SuspiciousUsers = M365AzureADAudit_CL
    | where TimeGenerated > TimeRange
    | where Operation_s =~ "UserLoginFailed"
    | summarize FailedLogins = count() by UserId_s
    | where FailedLogins > 5
    | project UserId_s;
union M365*_CL
| where TimeGenerated > TimeRange
| where UserId_s in (SuspiciousUsers)
| where Type !contains "Summary" and Type !contains "Error"
| summarize ActivityCount = count() by Type, UserId_s, UserDisplayName_s
| order by ActivityCount desc
```

---

## 📚 Query Categories Quick Reference

| Category | Focus | Key Tables |
|----------|-------|------------|
| 🔐 **Security** | Threats, anomalies, violations | M365AzureADAudit_CL, M365DLP*_CL |
| 📧 **Exchange** | Email, calendars, mailboxes | M365ExchangeAudit_CL |
| 📁 **SharePoint** | Files, sharing, collaboration | M365SharePointAudit_CL |
| 👥 **Teams** | Meetings, chats, calls | M365TeamsAudit_CL |
| 📊 **Compliance** | Retention, labels, policies | All tables + M365SensitivityLabels_CL |
| 📈 **Performance** | Collection health, trends | M365AuditCollectionSummary_CL |

💡 **Pro Tip**: Bookmark frequently used queries and create Azure Workbooks for ongoing monitoring!
