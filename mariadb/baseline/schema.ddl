/*M!999999\- enable the sandbox mode */ 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;
DROP TABLE IF EXISTS `ApiResourceClaims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiResourceClaims` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Type` varchar(200) NOT NULL,
  `ApiResourceId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiResourceClaims_ApiResourceId_Type` (`ApiResourceId`,`Type`),
  CONSTRAINT `FK_ApiResourceClaims_ApiResources_ApiResourceId` FOREIGN KEY (`ApiResourceId`) REFERENCES `ApiResources` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiResourceProperties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiResourceProperties` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Key` varchar(250) NOT NULL,
  `Value` varchar(2000) NOT NULL,
  `ApiResourceId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiResourceProperties_ApiResourceId_Key` (`ApiResourceId`,`Key`),
  CONSTRAINT `FK_ApiResourceProperties_ApiResources_ApiResourceId` FOREIGN KEY (`ApiResourceId`) REFERENCES `ApiResources` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiResourceScopes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiResourceScopes` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Scope` varchar(200) NOT NULL,
  `ApiResourceId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiResourceScopes_ApiResourceId_Scope` (`ApiResourceId`,`Scope`),
  CONSTRAINT `FK_ApiResourceScopes_ApiResources_ApiResourceId` FOREIGN KEY (`ApiResourceId`) REFERENCES `ApiResources` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiResourceSecrets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiResourceSecrets` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Description` varchar(1000) DEFAULT NULL,
  `Value` varchar(4000) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL,
  `Expiration` date DEFAULT NULL,
  `Type` varchar(250) NOT NULL,
  `Created` date NOT NULL,
  `ApiResourceId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ApiResourceSecrets_ApiResourceId` (`ApiResourceId`),
  CONSTRAINT `FK_ApiResourceSecrets_ApiResources_ApiResourceId` FOREIGN KEY (`ApiResourceId`) REFERENCES `ApiResources` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiResources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiResources` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Description` varchar(1000) DEFAULT NULL,
  `DisplayName` varchar(200) DEFAULT NULL,
  `Enabled` bit(1) NOT NULL,
  `Name` varchar(200) NOT NULL,
  `Created` datetime(6) NOT NULL DEFAULT '0001-01-01 00:00:00.000000',
  `LastAccessed` datetime(6) DEFAULT NULL,
  `NonEditable` tinyint(1) NOT NULL DEFAULT 0,
  `Updated` datetime(6) DEFAULT NULL,
  `AllowedAccessTokenSigningAlgorithms` varchar(100) DEFAULT NULL,
  `ShowInDiscoveryDocument` bit(1) NOT NULL,
  `RequireResourceIndicator` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiResources_Name` (`Name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiScopeClaims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiScopeClaims` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `ScopeId` int(11) DEFAULT NULL,
  `Type` varchar(200) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiScopeClaims_ScopeId_Type` (`ScopeId`,`Type`),
  CONSTRAINT `FK_ApiScopeClaims_ApiScopes_ScopeId` FOREIGN KEY (`ScopeId`) REFERENCES `ApiScopes` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiScopeProperties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiScopeProperties` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Key` varchar(250) NOT NULL,
  `Value` varchar(2000) NOT NULL,
  `ScopeId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiScopeProperties_ScopeId_Key` (`ScopeId`,`Key`),
  CONSTRAINT `FK_ApiScopeProperties_ApiScopes_ScopeId` FOREIGN KEY (`ScopeId`) REFERENCES `ApiScopes` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ApiScopes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ApiScopes` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Description` varchar(1000) DEFAULT NULL,
  `DisplayName` varchar(200) DEFAULT NULL,
  `Emphasize` bit(1) NOT NULL,
  `Name` varchar(200) NOT NULL,
  `Required` bit(1) NOT NULL,
  `ShowInDiscoveryDocument` bit(1) NOT NULL,
  `Enabled` bit(1) NOT NULL,
  `Created` datetime(6) NOT NULL DEFAULT '0001-01-01 00:00:00.000000',
  `LastAccessed` datetime(6) DEFAULT NULL,
  `NonEditable` tinyint(1) NOT NULL DEFAULT 0,
  `Updated` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ApiScopes_Name` (`Name`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetClaimTypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetClaimTypes` (
  `Id` varchar(127) NOT NULL,
  `ConcurrencyStamp` longtext DEFAULT NULL,
  `Description` longtext DEFAULT NULL,
  `Name` varchar(256) NOT NULL,
  `NormalizedName` varchar(256) DEFAULT NULL,
  `Required` bit(1) NOT NULL,
  `Reserved` bit(1) NOT NULL,
  `Rule` longtext DEFAULT NULL,
  `RuleValidationFailureDescription` longtext DEFAULT NULL,
  `UserEditable` bit(1) NOT NULL DEFAULT b'0',
  `ValueType` int(11) NOT NULL,
  `DisplayName` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `AK_AspNetClaimTypes_Name` (`Name`),
  UNIQUE KEY `ClaimTypeNameIndex` (`NormalizedName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetRoles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetRoles` (
  `Id` varchar(255) NOT NULL,
  `Name` varchar(256) DEFAULT NULL,
  `NormalizedName` varchar(256) DEFAULT NULL,
  `ConcurrencyStamp` longtext DEFAULT NULL,
  `Description` longtext DEFAULT NULL,
  `Reserved` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `RoleNameIndex` (`NormalizedName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetRoleClaims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetRoleClaims` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `RoleId` varchar(255) NOT NULL,
  `ClaimType` longtext DEFAULT NULL,
  `ClaimValue` longtext DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_AspNetRoleClaims_RoleId` (`RoleId`),
  CONSTRAINT `FK_AspNetRoleClaims_AspNetRoles_RoleId` FOREIGN KEY (`RoleId`) REFERENCES `AspNetRoles` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetUserClaims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetUserClaims` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `UserId` varchar(255) NOT NULL,
  `ClaimType` varchar(256) NOT NULL,
  `ClaimValue` longtext DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_AspNetUserClaims_UserId` (`UserId`),
  KEY `IX_AspNetUserClaims_ClaimType` (`ClaimType`),
  CONSTRAINT `FK_AspNetUserClaims_AspNetClaimTypes_ClaimType` FOREIGN KEY (`ClaimType`) REFERENCES `AspNetClaimTypes` (`Name`) ON DELETE CASCADE,
  CONSTRAINT `FK_AspNetUserClaims_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetUserLogins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetUserLogins` (
  `LoginProvider` varchar(255) NOT NULL,
  `ProviderKey` varchar(255) NOT NULL,
  `ProviderDisplayName` longtext DEFAULT NULL,
  `UserId` varchar(255) NOT NULL,
  PRIMARY KEY (`LoginProvider`,`ProviderKey`),
  KEY `IX_AspNetUserLogins_UserId` (`UserId`),
  CONSTRAINT `FK_AspNetUserLogins_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetUserRoles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetUserRoles` (
  `UserId` varchar(255) NOT NULL,
  `RoleId` varchar(255) NOT NULL,
  PRIMARY KEY (`UserId`,`RoleId`),
  KEY `IX_AspNetUserRoles_RoleId` (`RoleId`),
  CONSTRAINT `FK_AspNetUserRoles_AspNetRoles_RoleId` FOREIGN KEY (`RoleId`) REFERENCES `AspNetRoles` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_AspNetUserRoles_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetUserTokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetUserTokens` (
  `UserId` varchar(255) NOT NULL,
  `LoginProvider` varchar(255) NOT NULL,
  `Name` varchar(255) NOT NULL,
  `Value` longtext DEFAULT NULL,
  PRIMARY KEY (`UserId`,`LoginProvider`,`Name`),
  CONSTRAINT `FK_AspNetUserTokens_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AspNetUsers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AspNetUsers` (
  `Id` varchar(255) NOT NULL,
  `IsBlocked` tinyint(1) NOT NULL,
  `IsDeleted` tinyint(1) NOT NULL,
  `FirstName` longtext DEFAULT NULL,
  `LastName` longtext DEFAULT NULL,
  `UserName` varchar(256) DEFAULT NULL,
  `NormalizedUserName` varchar(256) DEFAULT NULL,
  `Email` varchar(256) DEFAULT NULL,
  `NormalizedEmail` varchar(256) DEFAULT NULL,
  `EmailConfirmed` tinyint(1) NOT NULL,
  `PasswordHash` longtext DEFAULT NULL,
  `SecurityStamp` longtext DEFAULT NULL,
  `ConcurrencyStamp` longtext DEFAULT NULL,
  `PhoneNumber` longtext DEFAULT NULL,
  `PhoneNumberConfirmed` tinyint(1) NOT NULL,
  `TwoFactorEnabled` tinyint(1) NOT NULL,
  `LockoutEnd` datetime(6) DEFAULT NULL,
  `LockoutEnabled` tinyint(1) NOT NULL,
  `AccessFailedCount` int(11) NOT NULL,
  `NormalizedFirstName` varchar(256) DEFAULT NULL,
  `NormalizedLastName` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UserNameIndex` (`NormalizedUserName`),
  KEY `EmailIndex` (`NormalizedEmail`),
  KEY `CountIndex` (`IsBlocked`,`IsDeleted`),
  KEY `CountIndexReversed` (`IsDeleted`,`IsBlocked`),
  KEY `FirstNameIndex` (`NormalizedFirstName`),
  KEY `LastNameIndex` (`NormalizedLastName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `AuditEntries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `AuditEntries` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `When` datetime(6) NOT NULL,
  `Source` longtext DEFAULT NULL,
  `SubjectType` longtext DEFAULT NULL,
  `SubjectIdentifier` longtext DEFAULT NULL,
  `Subject` longtext DEFAULT NULL,
  `Action` longtext DEFAULT NULL,
  `ResourceType` longtext DEFAULT NULL,
  `Resource` longtext DEFAULT NULL,
  `ResourceIdentifier` longtext DEFAULT NULL,
  `Succeeded` tinyint(1) NOT NULL,
  `Description` longtext DEFAULT NULL,
  `NormalisedSubject` longtext DEFAULT NULL,
  `NormalisedAction` longtext DEFAULT NULL,
  `NormalisedResource` longtext DEFAULT NULL,
  `NormalisedSource` longtext DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_AuditEntries_When` (`When`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientClaims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientClaims` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Type` varchar(250) NOT NULL,
  `Value` varchar(250) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientClaims_ClientId_Type_Value` (`ClientId`,`Type`,`Value`),
  CONSTRAINT `FK_ClientClaims_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientCorsOrigins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientCorsOrigins` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Origin` varchar(150) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientCorsOrigins_ClientId_Origin` (`ClientId`,`Origin`),
  CONSTRAINT `FK_ClientCorsOrigins_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientGrantTypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientGrantTypes` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `GrantType` varchar(250) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientGrantTypes_ClientId_GrantType` (`ClientId`,`GrantType`),
  CONSTRAINT `FK_ClientGrantTypes_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientIdPRestrictions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientIdPRestrictions` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Provider` varchar(200) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientIdPRestrictions_ClientId_Provider` (`ClientId`,`Provider`),
  CONSTRAINT `FK_ClientIdPRestrictions_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientPostLogoutRedirectUris`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientPostLogoutRedirectUris` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `PostLogoutRedirectUri` varchar(400) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientPostLogoutRedirectUris_ClientId_PostLogoutRedirectUri` (`ClientId`,`PostLogoutRedirectUri`),
  CONSTRAINT `FK_ClientPostLogoutRedirectUris_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientProperties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientProperties` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `ClientId` int(11) NOT NULL,
  `Key` varchar(250) NOT NULL,
  `Value` varchar(2000) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientProperties_ClientId_Key` (`ClientId`,`Key`),
  CONSTRAINT `FK_ClientProperties_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientRedirectUris`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientRedirectUris` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `RedirectUri` varchar(400) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientRedirectUris_ClientId_RedirectUri` (`ClientId`,`RedirectUri`),
  CONSTRAINT `FK_ClientRedirectUris_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientScopes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientScopes` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Scope` varchar(200) NOT NULL,
  `ClientId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ClientScopes_ClientId_Scope` (`ClientId`,`Scope`),
  CONSTRAINT `FK_ClientScopes_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ClientSecrets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ClientSecrets` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `ClientId` int(11) NOT NULL,
  `Description` varchar(2000) DEFAULT NULL,
  `Value` varchar(4000) NOT NULL,
  `Expiration` datetime(6) DEFAULT NULL,
  `Type` varchar(250) NOT NULL,
  `Created` datetime(6) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ClientSecrets_ClientId` (`ClientId`),
  CONSTRAINT `FK_ClientSecrets_Clients_ClientId` FOREIGN KEY (`ClientId`) REFERENCES `Clients` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `Clients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `Clients` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Enabled` tinyint(1) NOT NULL,
  `ClientId` varchar(200) NOT NULL,
  `ProtocolType` varchar(200) NOT NULL,
  `RequireClientSecret` tinyint(1) NOT NULL,
  `ClientName` varchar(200) DEFAULT NULL,
  `Description` varchar(1000) DEFAULT NULL,
  `ClientUri` varchar(2000) DEFAULT NULL,
  `LogoUri` varchar(2000) DEFAULT NULL,
  `RequireConsent` tinyint(1) NOT NULL,
  `AllowRememberConsent` tinyint(1) NOT NULL,
  `AlwaysIncludeUserClaimsInIdToken` tinyint(1) NOT NULL,
  `RequirePkce` tinyint(1) NOT NULL,
  `AllowPlainTextPkce` tinyint(1) NOT NULL,
  `RequireRequestObject` tinyint(1) NOT NULL,
  `AllowAccessTokensViaBrowser` tinyint(1) NOT NULL,
  `RequireDPoP` tinyint(1) NOT NULL,
  `DPoPValidationMode` int(11) NOT NULL,
  `DPoPClockSkew` time(6) NOT NULL,
  `FrontChannelLogoutUri` varchar(2000) DEFAULT NULL,
  `FrontChannelLogoutSessionRequired` tinyint(1) NOT NULL,
  `BackChannelLogoutUri` varchar(2000) DEFAULT NULL,
  `BackChannelLogoutSessionRequired` tinyint(1) NOT NULL,
  `AllowOfflineAccess` tinyint(1) NOT NULL,
  `IdentityTokenLifetime` int(11) NOT NULL,
  `AllowedIdentityTokenSigningAlgorithms` varchar(100) DEFAULT NULL,
  `AccessTokenLifetime` int(11) NOT NULL,
  `AuthorizationCodeLifetime` int(11) NOT NULL,
  `ConsentLifetime` int(11) DEFAULT NULL,
  `AbsoluteRefreshTokenLifetime` int(11) NOT NULL,
  `SlidingRefreshTokenLifetime` int(11) NOT NULL,
  `RefreshTokenUsage` int(11) NOT NULL,
  `UpdateAccessTokenClaimsOnRefresh` tinyint(1) NOT NULL,
  `RefreshTokenExpiration` int(11) NOT NULL,
  `AccessTokenType` int(11) NOT NULL,
  `EnableLocalLogin` tinyint(1) NOT NULL,
  `IncludeJwtId` tinyint(1) NOT NULL,
  `AlwaysSendClientClaims` tinyint(1) NOT NULL,
  `ClientClaimsPrefix` varchar(200) DEFAULT NULL,
  `PairWiseSubjectSalt` varchar(200) DEFAULT NULL,
  `InitiateLoginUri` varchar(2000) DEFAULT NULL,
  `UserSsoLifetime` int(11) DEFAULT NULL,
  `UserCodeType` varchar(100) DEFAULT NULL,
  `DeviceCodeLifetime` int(11) NOT NULL,
  `CibaLifetime` int(11) DEFAULT NULL,
  `PollingInterval` int(11) DEFAULT NULL,
  `CoordinateLifetimeWithUserSession` tinyint(1) DEFAULT NULL,
  `Created` datetime(6) NOT NULL,
  `Updated` datetime(6) DEFAULT NULL,
  `LastAccessed` datetime(6) DEFAULT NULL,
  `NonEditable` tinyint(1) NOT NULL,
  `PushedAuthorizationLifetime` int(11) DEFAULT NULL,
  `RequirePushedAuthorization` tinyint(1) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_Clients_ClientId` (`ClientId`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ConfigurationEntries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ConfigurationEntries` (
  `Key` varchar(95) NOT NULL,
  `Value` longtext DEFAULT NULL,
  PRIMARY KEY (`Key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `DataProtectionKeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `DataProtectionKeys` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `FriendlyName` longtext DEFAULT NULL,
  `Xml` longtext DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `DeviceCodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `DeviceCodes` (
  `UserCode` varchar(200) NOT NULL,
  `DeviceCode` varchar(200) NOT NULL,
  `SubjectId` varchar(200) DEFAULT NULL,
  `SessionId` varchar(100) DEFAULT NULL,
  `ClientId` varchar(200) NOT NULL,
  `Description` varchar(200) DEFAULT NULL,
  `CreationTime` datetime(6) NOT NULL,
  `Expiration` datetime(6) NOT NULL,
  `Data` longtext NOT NULL,
  PRIMARY KEY (`UserCode`),
  UNIQUE KEY `IX_DeviceCodes_DeviceCode` (`DeviceCode`),
  KEY `IX_DeviceCodes_Expiration` (`Expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `EnumClaimTypeAllowedValues`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `EnumClaimTypeAllowedValues` (
  `ClaimTypeId` varchar(255) NOT NULL,
  `Value` varchar(255) NOT NULL,
  PRIMARY KEY (`ClaimTypeId`,`Value`),
  CONSTRAINT `FK_EnumClaimTypeAllowedValues_AspNetClaimTypes_ClaimTypeId` FOREIGN KEY (`ClaimTypeId`) REFERENCES `AspNetClaimTypes` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ExtendedApiResources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ExtendedApiResources` (
  `Id` varchar(127) NOT NULL,
  `ApiResourceName` varchar(200) NOT NULL,
  `NormalizedName` varchar(200) NOT NULL,
  `Reserved` bit(1) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `ApiNameIndex` (`ApiResourceName`),
  UNIQUE KEY `ApiResourceNameIndex` (`NormalizedName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ExtendedClients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ExtendedClients` (
  `Id` varchar(127) NOT NULL,
  `ClientId` varchar(200) NOT NULL,
  `Description` longtext DEFAULT NULL,
  `NormalizedClientId` varchar(200) NOT NULL,
  `NormalizedClientName` varchar(200) DEFAULT NULL,
  `Reserved` bit(1) NOT NULL,
  `ClientType` int(11) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IdIndex` (`ClientId`),
  UNIQUE KEY `ClientIdIndex` (`NormalizedClientId`),
  UNIQUE KEY `ClientNameIndex` (`NormalizedClientName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ExtendedIdentityResources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ExtendedIdentityResources` (
  `Id` varchar(127) NOT NULL,
  `IdentityResourceName` varchar(200) NOT NULL,
  `NormalizedName` varchar(200) NOT NULL,
  `Reserved` bit(1) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IdentityNameIndex` (`IdentityResourceName`),
  UNIQUE KEY `IdentityResourceNameIndex` (`NormalizedName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `IdentityProviders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `IdentityProviders` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Scheme` varchar(200) NOT NULL,
  `DisplayName` varchar(200) DEFAULT NULL,
  `Enabled` tinyint(1) NOT NULL,
  `Type` varchar(20) NOT NULL,
  `Properties` longtext DEFAULT NULL,
  `Created` datetime(6) NOT NULL,
  `Updated` datetime(6) DEFAULT NULL,
  `LastAccessed` datetime(6) DEFAULT NULL,
  `NonEditable` tinyint(1) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_IdentityProviders_Scheme` (`Scheme`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `IdentityResourceClaims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `IdentityResourceClaims` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `IdentityResourceId` int(11) NOT NULL,
  `Type` varchar(200) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_IdentityResourceClaims_IdentityResourceId_Type` (`IdentityResourceId`,`Type`),
  CONSTRAINT `FK_IdentityResourceClaims_IdentityResources_IdentityResourceId` FOREIGN KEY (`IdentityResourceId`) REFERENCES `IdentityResources` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `IdentityResourceProperties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `IdentityResourceProperties` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `IdentityResourceId` int(11) NOT NULL,
  `Key` varchar(250) NOT NULL,
  `Value` varchar(2000) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_IdentityResourceProperties_IdentityResourceId_Key` (`IdentityResourceId`,`Key`),
  CONSTRAINT `FK_IdentityResourceProperties_IdentityResources_IdentityResourc~` FOREIGN KEY (`IdentityResourceId`) REFERENCES `IdentityResources` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `IdentityResources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `IdentityResources` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Enabled` tinyint(1) NOT NULL,
  `Name` varchar(200) NOT NULL,
  `DisplayName` varchar(200) DEFAULT NULL,
  `Description` varchar(1000) DEFAULT NULL,
  `Required` tinyint(1) NOT NULL,
  `Emphasize` tinyint(1) NOT NULL,
  `ShowInDiscoveryDocument` tinyint(1) NOT NULL,
  `Created` datetime(6) NOT NULL,
  `Updated` datetime(6) DEFAULT NULL,
  `NonEditable` tinyint(1) NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_IdentityResources_Name` (`Name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `Keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `Keys` (
  `Id` varchar(255) NOT NULL,
  `Version` int(11) NOT NULL,
  `Created` datetime(6) NOT NULL,
  `Use` varchar(255) DEFAULT NULL,
  `Algorithm` varchar(100) NOT NULL,
  `IsX509Certificate` tinyint(1) NOT NULL,
  `DataProtected` tinyint(1) NOT NULL,
  `Data` longtext NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_Keys_Use` (`Use`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `PersistedGrants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `PersistedGrants` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Key` varchar(200) DEFAULT NULL,
  `Type` varchar(50) NOT NULL,
  `SubjectId` varchar(200) DEFAULT NULL,
  `SessionId` varchar(100) DEFAULT NULL,
  `ClientId` varchar(200) NOT NULL,
  `Description` varchar(200) DEFAULT NULL,
  `CreationTime` datetime(6) NOT NULL,
  `Expiration` datetime(6) DEFAULT NULL,
  `ConsumedTime` datetime(6) DEFAULT NULL,
  `Data` longtext NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_PersistedGrants_Key` (`Key`),
  KEY `IX_PersistedGrants_ConsumedTime` (`ConsumedTime`),
  KEY `IX_PersistedGrants_Expiration` (`Expiration`),
  KEY `IX_PersistedGrants_SubjectId_ClientId_Type` (`SubjectId`,`ClientId`,`Type`),
  KEY `IX_PersistedGrants_SubjectId_SessionId_Type` (`SubjectId`,`SessionId`,`Type`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `PushedAuthorizationRequests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `PushedAuthorizationRequests` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ReferenceValueHash` varchar(64) NOT NULL,
  `ExpiresAtUtc` datetime(6) NOT NULL,
  `Parameters` longtext NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_PushedAuthorizationRequests_ReferenceValueHash` (`ReferenceValueHash`),
  KEY `IX_PushedAuthorizationRequests_ExpiresAtUtc` (`ExpiresAtUtc`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `RelyingParties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `RelyingParties` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Realm` varchar(200) NOT NULL,
  `TokenType` longtext DEFAULT NULL,
  `SignatureAlgorithm` longtext DEFAULT NULL,
  `DigestAlgorithm` longtext DEFAULT NULL,
  `SamlNameIdentifierFormat` longtext DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_RelyingParties_Realm` (`Realm`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `RelyingPartyClaimMappings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `RelyingPartyClaimMappings` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `OriginalClaimType` varchar(250) NOT NULL,
  `NewClaimType` varchar(250) NOT NULL,
  `RelyingPartyId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_RelyingPartyClaimMappings_RelyingPartyId` (`RelyingPartyId`),
  CONSTRAINT `FK_RelyingPartyClaimMappings_RelyingParties_RelyingPartyId` FOREIGN KEY (`RelyingPartyId`) REFERENCES `RelyingParties` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `SamlArtifacts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `SamlArtifacts` (
  `Key` varchar(200) NOT NULL,
  `EntityId` varchar(200) NOT NULL,
  `MessageType` varchar(50) NOT NULL,
  `Message` longtext NOT NULL,
  `CreationTime` datetime(6) NOT NULL,
  `Expiration` datetime(6) NOT NULL,
  PRIMARY KEY (`Key`),
  KEY `IX_SamlArtifacts_Expiration` (`Expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServerSideSessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServerSideSessions` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Key` varchar(100) NOT NULL,
  `Scheme` varchar(100) NOT NULL,
  `SubjectId` varchar(100) NOT NULL,
  `SessionId` varchar(100) DEFAULT NULL,
  `DisplayName` varchar(100) DEFAULT NULL,
  `Created` datetime(6) NOT NULL,
  `Renewed` datetime(6) NOT NULL,
  `Expires` datetime(6) DEFAULT NULL,
  `Data` longtext NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ServerSideSessions_Key` (`Key`),
  KEY `IX_ServerSideSessions_DisplayName` (`DisplayName`),
  KEY `IX_ServerSideSessions_Expires` (`Expires`),
  KEY `IX_ServerSideSessions_SessionId` (`SessionId`),
  KEY `IX_ServerSideSessions_SubjectId` (`SubjectId`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServiceProviderArtifactResolutionServices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServiceProviderArtifactResolutionServices` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Binding` varchar(2000) NOT NULL,
  `Location` varchar(2000) NOT NULL,
  `Index` int(11) NOT NULL,
  `IsDefault` tinyint(1) NOT NULL,
  `ServiceProviderId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ServiceProviderArtifactResolutionServices_ServiceProviderId` (`ServiceProviderId`),
  CONSTRAINT `FK_ServiceProviderArtifactResolutionServices_ServiceProviders_S~` FOREIGN KEY (`ServiceProviderId`) REFERENCES `ServiceProviders` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServiceProviderAssertionConsumerServices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServiceProviderAssertionConsumerServices` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Binding` varchar(2000) NOT NULL,
  `Location` varchar(2000) NOT NULL,
  `Index` int(11) NOT NULL,
  `IsDefault` tinyint(1) NOT NULL,
  `ServiceProviderId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ServiceProviderAssertionConsumerServices_ServiceProviderId` (`ServiceProviderId`),
  CONSTRAINT `FK_ServiceProviderAssertionConsumerServices_ServiceProviders_Se~` FOREIGN KEY (`ServiceProviderId`) REFERENCES `ServiceProviders` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServiceProviderClaimMappings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServiceProviderClaimMappings` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `OriginalClaimType` varchar(250) NOT NULL,
  `NewClaimType` varchar(250) NOT NULL,
  `ServiceProviderId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ServiceProviderClaimMappings_ServiceProviderId` (`ServiceProviderId`),
  CONSTRAINT `FK_ServiceProviderClaimMappings_ServiceProviders_ServiceProvide~` FOREIGN KEY (`ServiceProviderId`) REFERENCES `ServiceProviders` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServiceProviderSignCertificates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServiceProviderSignCertificates` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Certificate` longblob NOT NULL,
  `ServiceProviderId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ServiceProviderSignCertificates_ServiceProviderId` (`ServiceProviderId`),
  CONSTRAINT `FK_ServiceProviderSignCertificates_ServiceProviders_ServiceProv~` FOREIGN KEY (`ServiceProviderId`) REFERENCES `ServiceProviders` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServiceProviderSingleLogoutServices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServiceProviderSingleLogoutServices` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Binding` varchar(2000) NOT NULL,
  `Location` varchar(2000) NOT NULL,
  `Index` int(11) NOT NULL,
  `IsDefault` tinyint(1) NOT NULL,
  `ServiceProviderId` int(11) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ServiceProviderSingleLogoutServices_ServiceProviderId` (`ServiceProviderId`),
  CONSTRAINT `FK_ServiceProviderSingleLogoutServices_ServiceProviders_Service~` FOREIGN KEY (`ServiceProviderId`) REFERENCES `ServiceProviders` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ServiceProviders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ServiceProviders` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `EntityId` varchar(200) NOT NULL,
  `EncryptionCertificate` longblob DEFAULT NULL,
  `SignAssertions` tinyint(1) NOT NULL,
  `EncryptAssertions` tinyint(1) NOT NULL,
  `RequireSamlMessageDestination` tinyint(1) NOT NULL,
  `AllowIdpInitiatedSso` tinyint(1) NOT NULL DEFAULT 0,
  `RequireAuthenticationRequestsSigned` tinyint(1) DEFAULT NULL,
  `ArtifactDeliveryBindingType` longtext DEFAULT NULL,
  `NameIdentifierFormat` longtext DEFAULT NULL,
  `RequireSignedArtifactResolveRequests` tinyint(1) DEFAULT NULL,
  `RequireSignedArtifactResponses` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_ServiceProviders_EntityId` (`EntityId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `__EFMigrationsHistory`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `__EFMigrationsHistory` (
  `MigrationId` varchar(150) NOT NULL,
  `ProductVersion` varchar(32) NOT NULL,
  PRIMARY KEY (`MigrationId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

