<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    xmlns:topicpull="http://dita-ot.sourceforge.net/ns/200704/topicpull"
    exclude-result-prefixes="xs"
    version="2.0">

  <xsl:param name="PRESERVE-KEYS" select="'no'"/>


  <xsl:template match="*[dita-ot:is-link(.) and contains(@keyref, '.') and not(@href) and $PRESERVE-KEYS='yes']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="href" select="concat('keyref://', @keyref)"/>
      <xsl:attribute name="format" select="'html'"/>
      <xsl:attribute name="scope" select="'peer'"/>
      <xsl:apply-templates mode="topicpull:add-usertext-PI" select="."/>
      <xsl:apply-templates select="*|comment()|processing-instruction()|text()"/>
      <!--TODO - add error for missing target text-->
    </xsl:copy>
  </xsl:template>

  <!-- Process a link in the related-links section. Retrieve link text, type, and
       description if possible (and not already specified locally). -->
  <xsl:template match="*[contains(@class, ' topic/link ') and contains(@keyref, '.') and not(@href) and $PRESERVE-KEYS='yes']">
    <xsl:param as="element()*" name="baseContextElement" tunnel="yes"/>
    <xsl:copy>
      <!--copy existing explicit attributes-->
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="href" select="concat('keyref://', @keyref)"/>
      <xsl:attribute name="format" select="'html'"/>
      <xsl:attribute name="scope" select="'peer'"/>

      <!--inherit attributes as needed-->
      <xsl:variable as="xs:string?" name="importance" select="dita-ot:get-inherited-attribute-value(., 'importance', ())"/>
      <xsl:if test="exists($importance)">
        <xsl:attribute name="importance" select="$importance"/>
      </xsl:if>
      <xsl:variable as="xs:string?" name="role" select="dita-ot:get-inherited-attribute-value(., 'role', ())"/>
      <xsl:if test="exists($role)">
        <xsl:attribute name="role" select="$role"/>
      </xsl:if>

      <!-- use local linktext, otherwise error-->
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/linktext ')]">
          <xsl:apply-templates/>
        </xsl:when>
        <xsl:otherwise>
          <!--TODO - add error for missing target text-->
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
