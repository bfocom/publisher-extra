<!--

This document is an XSLT stylesheet which can be applied to a
CII XML document (with a root of <rsm:CrossIndustryInvoice>)
to convert it to HTML.

When used with BFO Publisher, the PDF genrated from the
XML will be factur-x compliant.

This is a technology demonstrator only! There are fields in
the XML we are ignoring. Please view it as a useful starting
point for your own invoices rather than a finished product.
In particular we haven't filled out most of the lookups (see
the last few templates), just enough to run the examples
included with the Factur-X specification. The "BT" and "BG"
labels for sections also refer to that specification.

-->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
  xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
  xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
  html="http://www.w3.org/1999/xhtml">

 <xsl:output indent="yes" method="xml" encoding="UTF-8" media-type="application/xml+xhtml"/>
 <xsl:decimal-format decimal-separator="." grouping-separator="," NaN="" />
 <xsl:template match="node()|@*" />

 <!-- MAIN HTML -->
 <xsl:template match="/rsm:CrossIndustryInvoice">
  <html lang="en">
   <head>
    <meta charset="UTF-8"/>
    <meta name="bfo-pdf-profile" content="factur-x-en16931 pdf/ua-1"/>
    <link rel="stylesheet" href="invoice.css"/>
    <link rel="attachment/alternative" href="#" name="factur-x.xml"/>
    <title>
     <xsl:call-template name="LookupDocumentType">
      <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:TypeCode"/>
     </xsl:call-template>
     <xsl:text> </xsl:text>
     <xsl:value-of select="//rsm:ExchangedDocument/ram:ID/text()"/>
    </title>
    <meta name="author">
     <xsl:attribute name="content">
      <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:Name"/>
     </xsl:attribute>
    </meta>
   </head>
   <body>

    <img id="logo" alt="Seller company logo" src="logo.svg"/>
    <h1 class="BT-3">
     <xsl:call-template name="BT-3"/><!-- document type -->
    </h1>

    <div class="seller">
     <xsl:call-template name="BT-27"/><!-- seller name -->
     <xsl:call-template name="BT-28"/><!-- seller trading name -->
     <xsl:call-template name="BG-6"/><!-- seller address-->
     <xsl:call-template name="BT-29"/><!-- seller id -->
     <xsl:call-template name="BT-30"/><!-- seller global id -->
     <xsl:call-template name="BT-31"/><!-- seller tax registrations -->
    </div>

    <div class="buyer">
     <h2>Bill To</h2>
     <xsl:call-template name="BT-44"/><!-- seller name -->
     <xsl:call-template name="BT-45"/><!-- seller trading name -->
     <xsl:call-template name="BG-8"/><!-- seller address-->
     <xsl:call-template name="BT-46"/><!-- seller id -->
     <xsl:call-template name="BT-47"/><!-- seller global id -->
     <xsl:call-template name="BT-48"/><!-- seller tax registrations -->
    </div>

    <div class="document">
     <p>
      <xsl:call-template name="BT-1"/><!-- invoice number -->
     </p>
     <p>
      <xsl:call-template name="BT-2"/><!-- invoice date -->
     </p>
     <p>
      <xsl:call-template name="BT-83"/><!-- seller reference -->
     </p>
     <p>
      <xsl:call-template name="BT-10"/><!-- buyer reference -->
     </p>
     <p>
      <xsl:call-template name="BT-13"/><!-- buyer purchase order-->
     </p>
     <p>
      <xsl:call-template name="BT-9"/><!-- due date-->
     </p>
     <p>
      <xsl:call-template name="BT-5"/><!-- currency-->
     </p>
    </div>

    <table class="items">
     <thead>
      <tr>
       <th scope="col" class="unit-count">Quantity</th>
       <th scope="col" class="item-code">Code</th>
       <th scope="col" class="item-description">Description</th>
       <th scope="col" class="unit-price">Unit Price</th>
       <th scope="col" class="line-tax">VAT</th>
       <th scope="col" class="line-total">Total</th>
      </tr>
     </thead>
     <tbody class="lines">
      <xsl:call-template name="BG-25"/><!-- line items -->
     </tbody>
     <tbody class="totals">
      <xsl:call-template name="BG-22"/><!-- totals -->
     </tbody>
    </table>

    <xsl:call-template name="BG-17"/><!-- payment details -->

    <xsl:call-template name="BG-1"/><!-- notes -->

    <footer>
     Factur-X Invoice created with BFO Publisher  •  publisher.bfo.com
     <img id="facturx-logo" alt="Factur-X logo" src="factur-x-basic.png"/>
    </footer>

   </body>
  </html>
 </xsl:template>

 <!-- XXXXXXXXXXX    Templates below here    XXXXXXXXXXXX  -->

 <xsl:template name="BT-1">
  <!-- BT-1: Invoice number (required) -->
  <span class="key">
   <xsl:call-template name="LookupDocumentTypeEN16931"/>
   No.
  </span>
  <span class="BT BT-1 number value">
   <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID"/>
  </span>
 </xsl:template>

 <xsl:template name="BT-2">
  <!-- BT-2: Invoice issue date (required) -->
  <span class="key">Date</span>
  <span class="BT BT-2 date value">
   <xsl:call-template name="DateTimeString">
    <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString"/>
   </xsl:call-template>
  </span>
 </xsl:template>

 <xsl:template name="BT-3">
  <!-- BT-3: Document type - Invoice, Credit Note etc (required) -->
  <xsl:call-template name="LookupDocumentType">
   <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:TypeCode"/>
  </xsl:call-template>
 </xsl:template>

 <xsl:template name="BT-5">
  <!-- BT-5: Currency code (required) -->
  <span class="key">Currency</span>
  <span class="BT BT-5 currency value">
   <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode"/>
  </span>
 </xsl:template>

 <xsl:template name="BT-9">
  <!-- BT-9: Invoice due date -->
  <xsl:if test="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime">
  <span class="key">Due date</span>
   <span class="BT BT-9 due-date value">
    <xsl:call-template name="DateTimeString">
     <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime/udt:DateTimeString"/>
    </xsl:call-template>
   </span>
  </xsl:if>
 </xsl:template>

 <!-- XXXXXXXXXXX    Seller Templates   XXXXXXXXXXXX  -->

 <xsl:template name="BT-27">
  <!-- BT-27: Seller Name (required) -->
  <p class="BT BT-27 company-name">
   <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:Name"/>
  </p>
 </xsl:template>

 <xsl:template name="BT-28">
  <!-- BT-28: Seller Trading Name -->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:SpecifiedLegalOrganization/ram:TradingBusinessName) != ''">
   <p class="BT BT-28 company-trading-name">
    <span class="key">
     Trading As
    </span>
    <span class="value">
     <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:SpecifiedLegalOrganization/ram:TradingBusinessName"/>
    </span>
   </p>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-29">
  <!-- BT-29: Seller Global ID -->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:GlobalID) != ''">
   <p class="BT BT-29 company-global-id">
    <xsl:call-template name="LookupISO6523">
     <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:GlobalID"/>
    </xsl:call-template>
   </p>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-30">
  <!-- BT-30: Seller ID -->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:ID) != ''">
   <p class="BT BT-30 company-id">
    <xsl:call-template name="LookupISO6523">
     <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:ID"/>
    </xsl:call-template>
   </p>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-31">
  <!-- BT-31: Seller VAT/Tax ID -->
  <xsl:for-each select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:SpecifiedTaxRegistration">
   <p class="BT BT-31 company-tax-registration">
    <xsl:call-template name="SpecifiedTaxRegistration"/>
   </p>
  </xsl:for-each>
 </xsl:template>

 <xsl:template name="BG-6">
  <!-- BG-6: Seller Address (required) -->
  <div class="BG BG-6 company-address" >
   <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:PostalTradeAddress"/>
  </div>
 </xsl:template>

 <!-- XXXXXXXXXXX    Buyer Templates   XXXXXXXXXXXX  -->

 <xsl:template name="BT-44">
  <!-- BT-44: Buyer Name (required) -->
  <p class="BT BT-44 company-name">
   <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:Name"/>
  </p>
 </xsl:template>

 <xsl:template name="BT-45">
  <!-- BT-45: Buyer Trading Name -->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:SpecifiedLegalOrganization/ram:TradingBusinessName) != ''">
   <p class="BT BT-45 company-trading-name">
    <span class="key">
     Trading As
    </span>
    <span class="value">
     <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:SpecifiedLegalOrganization/ram:TradingBusinessName"/>
    </span>
   </p>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-46">
  <!-- BT-46: Buyer Global ID -->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:GlobalID) != ''">
   <p class="BT BT-46 company-global-id">
    <xsl:call-template name="LookupISO6523">
     <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:GlobalID"/>
    </xsl:call-template>
   </p>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-47">
  <!-- BT-47: Buyer ID -->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:ID) != ''">
   <p class="BT BT-47 company-id">
    <xsl:call-template name="LookupISO6523">
     <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:ID"/>
    </xsl:call-template>
   </p>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-48">
  <!-- BT-48: Buyer VAT/Tax ID -->
  <xsl:for-each select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:SpecifiedTaxRegistration">
   <p class="BT BT-48 company-tax-registration">
    <xsl:call-template name="SpecifiedTaxRegistration"/>
   </p>
  </xsl:for-each>
 </xsl:template>

 <xsl:template name="BG-8">
  <!-- BG-8: Buyer Address (required) -->
  <div class="BG BG-8 company-address" >
   <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:PostalTradeAddress"/>
  </div>
 </xsl:template>

 <xsl:template name="BT-10">
  <!-- BT-10: Buyer reference-->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerReference) != ''">
   <span class="key">Your Ref</span>
   <span class="BT BT-10 buyer-reference">
    <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerReference"/>
   </span>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-13">
  <!-- BT-13: Buyer purchase order reference-->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID) != ''">
   <span class="key">Order No.</span>
   <span class="BT BT-13 buyer-purchase-order value">
    <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerOrderReferencedDocument/ram:IssuerAssignedID"/>
   </span>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BT-83">
  <!-- BT-83: Seller reference-->
  <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:PaymentReference) != ''">
   <span class="key">Our Ref</span>
   <span class="BT BT-83 seller-reference value">
    <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:PaymentReference"/>
   </span>
  </xsl:if>
 </xsl:template>

 <!-- XXXXXXXXXXX    Item Table Templates   XXXXXXXXXXXX  -->

 <xsl:template name="BG-25">
  <!-- BG-25: line items -->
  <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem"/>
 </xsl:template>

 <xsl:template name="BG-17">
  <!-- BG-17: payment method and creditor account details -->
  <xsl:if test="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans">
   <div class="BG BG-17 payment-method">
    <p class="payment-method-description">
     <xsl:choose>
      <xsl:when test="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:Information">
       <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:Information"/>
      </xsl:when>
      <xsl:otherwise>
       <xsl:call-template name="LookupPayment">
        <xsl:with-param name="ctx" select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode"/>
       </xsl:call-template>
      </xsl:otherwise>
     </xsl:choose>
    </p>

    <div class="payment-method-account">
     <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:AccountName) != ''">
      <p>
       <span class="key">
        Account
       </span>
       <span class="value">
        <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:AccountName"/>
       </span>
      </p>
     </xsl:if>

     <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:IBANID) != ''">
      <p>
       <span class="key">
        IBAN
       </span>
       <span class="value">
        <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:IBANID"/>
       </span>
      </p>
     </xsl:if>

     <xsl:if test="normalize-space(/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeeSpecifiedCreditorFinancialInstitution)!=''">
      <p>
       <span class="key">
        SWIFT / BIC
       </span>
       <span class="value">
        <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeeSpecifiedCreditorFinancialInstitution"/>
       </span>
      </p>
     </xsl:if>
    </div>

   </div>
  </xsl:if>
 </xsl:template>

 <xsl:template name="BG-1">
  <!-- BG-1: notes -->
  <div class="BG BG-1 notes">
   <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:IncludedNote"/>
  </div>
 </xsl:template>

 <xsl:template match="ram:IncludedSupplyChainTradeLineItem">
  <!-- actually do BG-25: An individual item line -->
  <tr class="BG BG-25 line">
   <td class="unit-count">
    <xsl:call-template name="LookupUnit">
     <xsl:with-param name="ctx" select="ram:SpecifiedLineTradeDelivery/ram:BilledQuantity"/>
    </xsl:call-template>
   </td>
   <td class="item-code">
    <xsl:if test="ram:SpecifiedTradeProduct/ram:GlobalID">
     <xsl:call-template name="LookupISO6523">
      <xsl:with-param name="ctx" select="ram:SpecifiedTradeProduct/ram:GlobalID"/>
     </xsl:call-template>
    </xsl:if>
   </td>
   <td class="item-description">
    <xsl:value-of select="ram:SpecifiedTradeProduct/ram:Name"/>
   </td>
   <td class="unit-price">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="ram:SpecifiedLineTradeAgreement/ram:NetPriceProductTradePrice/ram:ChargeAmount"/>
    </xsl:call-template>
   </td>
   <td class="line-tax">
    <xsl:call-template name="Percentage">
     <xsl:with-param name="ctx" select="ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax"/>
    </xsl:call-template>
   </td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount"/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template name="BG-22">
  <!-- BG-22: totals items -->
  <xsl:if test="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:ChargeTotalAmount[number(text()) != 0] and /rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:ChargeTotalAmount[number(text()) != 0]">
   <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:LineTotalAmount"/>
   <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:ChargeTotalAmount[number(text()) != 0]"/>
   <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:AllowanceTotalAmount[number(text()) != 0]"/>
  </xsl:if>
  <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxBasisTotalAmount"/>
  <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxTotalAmount"/>
  <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:GrandTotalAmount"/>
  <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TotalPrepaidAmount[number(text()) != 0]"/>
  <xsl:apply-templates select="/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:DuePayableAmount"/>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:LineTotalAmount">
  <!-- BT-106: The total of the individual lines -->
  <tr class="BT BT-106 total-lines">
   <td colspan="5">Sub-Total</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:ChargeTotalAmount[number(text()) != 0]">
  <!-- BT-108: The total of any charges -->
  <tr class="BT BT-108 total-charges">
   <td colspan="5">Additional Charges</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:AllowanceTotalAmount[number(text()) != 0]">
  <!-- BT-107: The total of any allowances -->
  <tr class="BT BT-107 total-allowances">
   <td colspan="5">Less Allowances</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxBasisTotalAmount">
  <!-- BT-109: The total amount of the Invoice without VAT -->
  <tr class="BT BT-109 total-net">
   <td colspan="5">Net Total</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxTotalAmount">
  <!-- BT-110: The total VAT amount for the Invoice. -->
  <tr class="BT BT-110 total-tax">
   <td colspan="5">VAT</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:GrandTotalAmount">
  <!-- BT-112: The total amount of the Invoice with VAT -->
  <tr class="BT BT-112 total-grand">
   <td colspan="5">Grand Total</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TotalPrepaidAmount">
  <!-- BT-113: The sum of amounts which have been paid in advance -->
  <tr class="BT BT-113 total-paid">
   <td colspan="5">Already paid</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:DuePayableAmount">
  <!-- BT-115: The outstanding amount that is requested to be paid. -->
  <tr class="BT BT-115 total-due">
   <td colspan="5">Due</td>
   <td class="line-total">
    <xsl:call-template name="Amount">
     <xsl:with-param name="ctx" select="."/>
    </xsl:call-template>
   </td>
  </tr>
 </xsl:template>

 <xsl:template match="ram:IncludedNote">
  <div class="note">
   <xsl:if test="ram:SubjectCode">
    <h3>
     <xsl:call-template name="LookupText">
      <xsl:with-param name="ctx" select="ram:SubjectCode"/>
     </xsl:call-template>
    </h3>
   </xsl:if>
   <p>
    <xsl:value-of select="ram:Content"/>
   </p>
  </div>
 </xsl:template>

 <xsl:template match="ram:PostalTradeAddress">
  <p class="address">
   <xsl:if test="ram:LineOne">
    <span><xsl:value-of select="ram:LineOne"/></span>
   </xsl:if>
   <xsl:if test="ram:LineTwo">
    <span><xsl:value-of select="ram:LineTwo"/></span>
   </xsl:if>
   <xsl:if test="ram:LineThree">
    <span><xsl:value-of select="ram:LineThree"/></span>
   </xsl:if>
   <span>
    <xsl:if test="ram:CityName">
     <xsl:value-of select="ram:CityName"/>
     <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:if test="ram:PostcodeCode">
     <xsl:value-of select="ram:PostcodeCode"/>
     <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:if test="ram:CountrySubDivisionName">
     <xsl:value-of select="ram:CountrySubDivisionName"/>
    </xsl:if>
   </span>
   <span><xsl:value-of select="ram:CountryID"/></span>
   <xsl:apply-templates select="../ram:URIUniversalCommunication"/>
  </p>
 </xsl:template>


 <!-- XXXXXXXXXXX    Field Templates and Lookups - called from above  XXXXXXXXXXXX  -->


 <xsl:template name="Percentage">
  <xsl:param name="ctx"/>
  <xsl:value-of select="format-number($ctx/ram:RateApplicablePercent, '0.0')"/>
  <xsl:text>%</xsl:text>
 </xsl:template>

 <xsl:template name="Amount">
  <xsl:param name="ctx"/>
  <span class="currency">
   <xsl:value-of select="$ctx/@currencyID"/>
  </span>
  <xsl:value-of select="format-number($ctx, '###,##0.00')"/>
 </xsl:template>

 <xsl:template name="DateTimeString">
  <xsl:param name="ctx"/>
  <xsl:choose>
   <xsl:when test="$ctx/@format='102'">
    <xsl:value-of select="substring($ctx/text(), 7, 2)" />
    <xsl:text> </xsl:text>
    <xsl:choose>
     <xsl:when test="substring($ctx/text(), 5, 2) = '01'">January</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '02'">February</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '03'">March</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '04'">April</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '05'">May</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '06'">June</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '07'">July</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '08'">August</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '09'">September</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '10'">October</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '11'">November</xsl:when>
     <xsl:when test="substring($ctx/text(), 5, 2) = '12'">December</xsl:when>
    </xsl:choose>
    <xsl:text> </xsl:text>
    <xsl:value-of select="substring($ctx/text(), 1, 4)" />
   </xsl:when>
   <xsl:otherwise>
    <xsl:message terminate="yes">Invalid date format <xsl:value-of select="$ctx/@format"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="SpecifiedTaxRegistration">
  <span class="key">
   <xsl:call-template name="LookupReferenceCodeQualifier">
    <xsl:with-param name="ctx" select="ram:ID/@schemeID"/>
   </xsl:call-template>
  </span>
  <span class="value"><xsl:value-of select="ram:ID"/></span>
 </xsl:template>

 <xsl:template name="LookupDocumentType">
  <!-- UNTDID 1001 — Document type - Tab name "1001" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <xsl:choose>
   <xsl:when test="$ctx = '204'">Payment Valuation</xsl:when>
   <xsl:when test="$ctx = '325'">Proforma Invoice</xsl:when>
   <xsl:when test="$ctx = '380'">Commercial Invoice</xsl:when>
   <xsl:when test="$ctx = '381'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '382'">Debit Note</xsl:when>
   <xsl:when test="$ctx = '384'">Corrected Invoice</xsl:when>
   <xsl:when test="$ctx = '387'">Hire Invoice</xsl:when>
   <xsl:when test="$ctx = '389'">Self-Billed Invoice</xsl:when>
   <xsl:when test="$ctx = '575'">Insurer's Invoice</xsl:when>
   <xsl:when test="$ctx = '751'">Invoice Information</xsl:when>
   <!-- Many more TODO -->
   <xsl:otherwise>
    <xsl:message terminate="yes">Unknown Document Type <xsl:value-of select="$ctx"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="LookupDocumentTypeEN16931">
  <!-- UNTDID 1001 — Document type - Tab name "1001" in Factur-X spec spreadsheet -->
  <!-- This is the "EN16931" interpretation - invoice or credit note -->
  <xsl:variable name="ctx">
   <xsl:value-of select="/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:TypeCode"/>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="$ctx = '81'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '83'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '261'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '262'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '296'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '308'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '381'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '396'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '420'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '458'">Credit Note</xsl:when>
   <xsl:when test="$ctx = '532'">Credit Note</xsl:when>
   <xsl:otherwise>Invoice</xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="LookupISO6523">
  <!-- ISO/IEC 6523 — Identifier scheme code - Tab name "ICD" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <span class="key">
   <xsl:choose>
    <xsl:when test="$ctx/@schemeID = false()">ID</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0002'">SIRENE</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0009'">SIRET</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0021'">SWIFT</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0060'">DUNS</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0088'">EAN</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0160'">GTIN</xsl:when>
    <xsl:when test="$ctx/@schemeID = '0177'">ODETTE</xsl:when>
   <!-- Many more TODO -->
    <xsl:otherwise>
     <xsl:message terminate="yes">Unknown ISO6523 code <xsl:value-of select="$ctx/@schemeID"/></xsl:message>
    </xsl:otherwise>
   </xsl:choose>
  </span>
  <span class="value">
   <xsl:value-of select="$ctx"/>
  </span>
 </xsl:template>

 <xsl:template name="LookupReferenceCodeQualifier">
  <!-- UNTDID 1153 — Reference code qualifier - Tab name "1153" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <xsl:choose>
   <xsl:when test="$ctx = 'FC'">Fiscal Number</xsl:when>
   <xsl:when test="$ctx = 'VA'">VAT Number</xsl:when>
   <!-- Many more TODO -->
   <xsl:otherwise>
    <xsl:message terminate="yes">Unknown Reference Code Qualifier <xsl:value-of select="$ctx"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="LookupEAS">
  <!-- CEF EAS — Electronic address scheme identifier - Tab name "EAS" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <xsl:choose>
   <xsl:when test="$ctx = '0002'">SIRENE</xsl:when>
   <xsl:when test="$ctx = '0009'">SIRET</xsl:when>
   <xsl:when test="$ctx = '0060'">DUNS</xsl:when>
   <xsl:when test="$ctx = '0088'">EAN Location</xsl:when>
   <xsl:when test="$ctx = '9958'">Leitweg ID</xsl:when>
   <xsl:when test="$ctx = 'EM'">E-Mail</xsl:when>
   <!-- Many more TODO -->
   <xsl:otherwise>
    <xsl:message terminate="yes">Unknown Electronic Address Scheme ID <xsl:value-of select="$ctx"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="LookupText">
  <!-- UNTDID 4451 — Text subject qualifier - Tab name "Text" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <xsl:choose>
   <xsl:when test="$ctx = 'AAA'">Description</xsl:when>
   <xsl:when test="$ctx = 'AAB'">Payment Terms</xsl:when>
   <xsl:when test="$ctx = 'AAG'">Party Instructions</xsl:when>
   <xsl:when test="$ctx = 'AAK'">Price Conditions</xsl:when>
   <xsl:when test="$ctx = 'AAI'">General Information</xsl:when>
   <xsl:when test="$ctx = 'AAJ'">Additional Sale Conditions</xsl:when>
   <xsl:when test="$ctx = 'AAX'">License Information</xsl:when>
   <xsl:when test="$ctx = 'ADU'">Note</xsl:when>
   <xsl:when test="$ctx = 'REG'">Regulatory Information</xsl:when>
   <xsl:when test="$ctx = 'TXD'">Tax Declaration</xsl:when>
   <!-- Many more TODO -->
   <xsl:otherwise>
    <xsl:message terminate="yes">Unknown Text-4451 code <xsl:value-of select="$ctx"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="LookupUnit">
  <!-- UN/ECE Recommendation N°20 and UN/ECE Recommendation N°21 — Unit codes - Tab name "UNIT" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <xsl:value-of select="format-number($ctx, '#.#')"/>
  <xsl:choose>
   <xsl:when test="$ctx/@unitCode = 'C62'"> item(s)</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'DAY'"> day(s)</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'HUR'"> hour(s)</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'H87'"> piece(s)</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'KGM'">kg</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'KMT'">km</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'KWH'">kW/hr</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'MTK'">m²</xsl:when>
   <xsl:when test="$ctx/@unitCode = 'XBC'"> bottle-crates</xsl:when>
   <!-- Many more TODO -->
   <xsl:otherwise>
    <xsl:message terminate="yes">Unknown Unit code <xsl:value-of select="$ctx/@unitCode"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="LookupPayment">
  <!-- UNTDID 4461 — Payment means - Tab name "Payment" in Factur-X spec spreadsheet -->
  <xsl:param name="ctx"/>
  <xsl:choose>
   <xsl:when test="$ctx/text() = '30'">Payment by credit transfer</xsl:when>
   <xsl:when test="$ctx/text() = '31'">Payment by debit transfer</xsl:when>
   <xsl:when test="$ctx/text() = '54'">Payment by credit card</xsl:when>
   <xsl:when test="$ctx/text() = '55'">Payment by debit card</xsl:when>
   <xsl:when test="$ctx/text() = '49'">Payment by direct debit</xsl:when>
   <xsl:when test="$ctx/text() = '58'">Payment by SEPA credit transfer</xsl:when>
   <xsl:when test="$ctx/text() = '59'">Payment by SEPA direct debit</xsl:when>
   <!-- Many more TODO -->
   <xsl:otherwise>
    <xsl:message terminate="yes">Unknown Payment code <xsl:value-of select="$ctx/text()"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

</xsl:stylesheet>
