# 🚀 M365 Audit Log Collector for Azure Sentinel

<div align="center">

![M365 Logo](https://img.shields.io/badge/Microsoft_365-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Sentinel](https://img.shields.io/badge/Azure_Sentinel-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)

**🔥 Enterprise-Grade M365 Audit Log Collection & Enrichment Solution 🔥**



</div>

---

## 🌟 Overview

This **enterprise-grade solution** collects Microsoft 365 audit logs via the Office 365 Management API and ingests them into **Azure Sentinel** with organized tables, **intelligent data enrichment**, and **automated deduplication**. 

### ✨ Why This Solution?
- 🎯 **Production-Ready**: Battle-tested code with proper error handling
- 🔐 **Secure**: Uses Azure Key Vault and Managed Identity
- 📊 **Enriched Data**: Automatic user details, sensitivity labels, and more
- ⚡ **High Performance**: Optimized for large-scale environments
- 🛡️ **Zero Duplicates**: Advanced deduplication ensures clean data
- 📈 **Scalable**: Handles millions of events seamlessly

### 🎭 What Makes This Special?

| Feature | Description | Impact |
|---------|-------------|---------|
| 🔄 **Auto-Enrichment** | Adds user details directly to audit logs | No complex joins needed |
| 🏷️ **Label Sync** | Syncs Microsoft Purview sensitivity labels | Complete compliance picture |
| 🚫 **Deduplication** | Eliminates duplicate events automatically | Clean, reliable data |
| ⚡ **Real-time** | Collects logs every 5 minutes | Near real-time visibility |
| 🔒 **Secure by Design** | Key Vault + Managed Identity | Zero secrets in code |
| 📊 **Organized Tables** | Separate tables by service type | Easy querying and analysis |

---

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Microsoft 365 │    │  Azure Function  │    │ Azure Sentinel  │
│                 │    │                  │    │                 │
│ • Exchange      │───▶│ • Collects Logs  │───▶│ • M365*_CL      │
│ • SharePoint    │    │ • Enriches Data  │    │ • Enriched      │
│ • Teams         │    │ • Deduplicates   │    │ • Organized     │
│ • Azure AD      │    │ • Monitors       │    │ • Query Ready   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 🔄 Data Flow
1. **📥 Collection**: Azure Function polls O365 Management API
2. **🔍 Processing**: Enriches with user details from Microsoft Graph
3. **🎯 Deduplication**: Removes duplicates using intelligent hashing
4. **📤 Ingestion**: Sends to Log Analytics in organized tables

---

## 📊 Data Tables Created

| Table Name | Content | Enrichment |
|------------|---------|------------|
| `M365ExchangeAudit_CL` | Exchange mailbox activities | ✅ User details |
| `M365SharePointAudit_CL` | SharePoint & OneDrive | ✅ User details |
| `M365TeamsAudit_CL` | Teams meetings & chat | ✅ User details |
| `M365AzureADAudit_CL` | Sign-ins & directory changes | ✅ User details |
| `M365DLP*_CL` | Data Loss Prevention events | ✅ User details |
| `M365SensitivityLabels_CL` | Purview sensitivity labels | 📋 Reference data |
| `M365AuditCollectionSummary_CL` | Collection statistics | 📈 Monitoring |

---

## 🚀 Quick Start

### 📋 Prerequisites
- ✅ **Azure Subscription** with Contributor access
- ✅ **Microsoft 365** with Global Admin rights
- ✅ **PowerShell 7.4+** installed
- ✅ **Azure PowerShell modules** (auto-installed in Step 0)

### ⚡ 5-Step Deployment

Follow these scripts in order for a complete deployment:

#### 🔧 Step 0: Prerequisites Setup
```powershell
# Download and run the prerequisites script
.\Scripts\0-Prerequisites.ps1
```

#### 🆔 Step 1: Azure AD App Registration  
```powershell
# Creates app registration with required permissions
.\Scripts\1-AppRegistration.ps1
```

#### 🔌 Step 2: Enable O365 API Subscriptions
```powershell
# Enables M365 audit log collection
.\Scripts\2-EnableSubscriptions.ps1
```

#### ☁️ Step 3: Deploy Azure Infrastructure
```powershell
# Creates all Azure resources
.\Scripts\3-DeployInfrastructure.ps1
```

#### 📦 Step 4: Deploy Function Code
```powershell
# Deploys the collection function
.\Scripts\4-DeployFunction.ps1
```

#### ✅ Step 5: Validation & Monitoring
```powershell
# Validates deployment and provides monitoring queries
.\Scripts\5-Validation.ps1
```

---

## 📁 Repository Structure

```
📦 M365-Audit-Log-Collector
├── 📜 README.md                    # You are here!
├── 📄 LICENSE                      # MIT License
├── 📋 .gitignore                   # Git ignore rules
├── 📁 Scripts/                     # 🚀 Deployment Scripts
│   ├── 🔧 0-Prerequisites.ps1      # Prerequisites setup
│   ├── 🆔 1-AppRegistration.ps1    # Azure AD app creation
│   ├── 🔌 2-EnableSubscriptions.ps1 # O365 API enablement
│   ├── ☁️ 3-DeployInfrastructure.ps1 # Azure resources
│   ├── 📦 4-DeployFunction.ps1      # Function deployment
│   └── ✅ 5-Validation.ps1          # Deployment validation
├── 📁 FunctionApp/                 # 🔧 Azure Function Code
│   ├── 📄 host.json                # Function app configuration
│   ├── 📄 requirements.psd1        # PowerShell dependencies
│   ├── 📄 profile.ps1              # Function app profile
│   ├── 📁 Modules/                 # 📚 PowerShell Modules
│   │   ├── 🔌 O365Management.psm1  # O365 API interactions
│   │   ├── 📊 LogAnalytics.psm1    # Log Analytics ingestion
│   │   └── 🎯 Enrichment.psm1      # Data enrichment logic
│   └── 📁 CollectAuditLogs/        # 🎯 Main Function
│       ├── 📄 function.json        # Function configuration
│       └── 📄 run.ps1               # Main execution logic
├── 📁 Documentation/               # 📚 Additional Documentation
│   ├── 📖 DEPLOYMENT.md            # Detailed deployment guide
│   ├── 🔍 TROUBLESHOOTING.md       # Common issues & solutions
│   ├── 📊 QUERIES.md               # Useful KQL queries
│   └── 🔧 CONFIGURATION.md         # Advanced configuration
└── 📁 Examples/                    # 💡 Usage Examples
    ├── 📊 sample-queries.kql        # Sample KQL queries
    ├── 📈 monitoring-workbook.json  # Azure Workbook template
    └── 🚨 alert-rules.json          # Sample alert rules
```

---

## 🎯 Features Deep Dive

### 🔍 Intelligent Data Enrichment
- **👤 User Details**: Automatically adds display name, department, manager, job title
- **🏢 Organizational Data**: Includes office location and organizational hierarchy
- **🏷️ Sensitivity Labels**: Syncs Microsoft Purview labels for compliance
- **📍 Context Enhancement**: Adds meaningful context to raw audit events

### 🛡️ Advanced Security
- **🔐 Key Vault Integration**: All secrets stored securely
- **🆔 Managed Identity**: No hardcoded credentials
- **🔒 RBAC**: Principle of least privilege
- **🛡️ Encryption**: Data encrypted in transit and at rest

### ⚡ Performance Optimizations
- **🚀 Parallel Processing**: Multiple content types processed simultaneously
- **💾 Efficient Caching**: Reduces API calls with intelligent caching
- **🔄 Delta Queries**: Only collects new/changed data
- **📦 Batch Processing**: Optimized batch sizes for maximum throughput

---

## 📊 Monitoring & Alerting

### 📈 Built-in Monitoring
The solution creates comprehensive monitoring tables:

```kql
// Check collection health
M365AuditCollectionSummary_CL
| where TimeGenerated > ago(1h)
| project TimeGenerated, TotalRecords_d, Success_b, DurationSeconds_d
```

### 🚨 Recommended Alerts
- **⚠️ Collection Failures**: Alert when collection fails for 2+ cycles
- **📉 Low Volume**: Alert when record count drops significantly
- **⏱️ Long Duration**: Alert when collection takes too long
- **🔴 Error Rate**: Alert on high error rates

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### 🐛 Found a Bug?
1. Check existing [Issues](../../issues)
2. Create a new issue with detailed description
3. Include PowerShell version and error details

### 💡 Feature Requests
1. Check [Feature Requests](../../issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
2. Open a new issue with the `enhancement` label
3. Describe your use case and proposed solution

---

## 📞 Support

### 🆘 Need Help?
- 📖 Check our [Documentation](Documentation/)
- 🔍 Review [Troubleshooting Guide](Documentation/TROUBLESHOOTING.md)
- 💬 Open an [Issue](../../issues/new)

### 🏆 Success Stories
Using this solution successfully? We'd love to hear about it! Share your story in [Discussions](../../discussions).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Bilel Azaiez**  
*Cloud Solution Architect for Data Security @MSFT*

---

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/M365-Audit-Log-Collector&type=Date)](https://star-history.com/#yourusername/M365-Audit-Log-Collector&Date)

---

<div align="center">

**Made with ❤️ for the Data Security & Purview community**

*If this project helped you, please consider giving it a ⭐!*

</div>
