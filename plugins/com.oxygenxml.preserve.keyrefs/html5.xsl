<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">

  <!-- this is the existing template, copied from the DITA-OT -->

  <!-- Process standard attributes that may appear anywhere. Previously this was "setclass" -->
  <xsl:template name="commonattributes">
    <xsl:param name="default-output-class"/>
    <xsl:apply-templates select="@xml:lang"/>
    <xsl:apply-templates select="@dir"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:apply-templates select="." mode="set-output-class">
      <xsl:with-param name="default" select="$default-output-class"/>
    </xsl:apply-templates>
    <xsl:choose>
      <xsl:when test="exists($passthrough-attrs[empty(@att) and empty(@value)])">
        <xsl:variable name="specializations" as="xs:string*">
          <xsl:for-each select="ancestor-or-self::*[@domains][1]/@domains">
            <xsl:analyze-string select="normalize-space(.)" regex="a\(props (.+?)\)">
              <xsl:matching-substring>
                <xsl:sequence select="tokenize(regex-group(1), '\s+')"/>
              </xsl:matching-substring>
            </xsl:analyze-string>
          </xsl:for-each>
        </xsl:variable>
        <xsl:for-each select="@props |
                              @audience |
                              @platform |
                              @product |
                              @otherprops |
                              @deliveryTarget |
                              @*[local-name() = $specializations]">
          <xsl:attribute name="data-{name()}" select="."/>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="exists($passthrough-attrs)">
        <xsl:for-each select="@*">
          <xsl:if test="$passthrough-attrs[@att = name(current()) and (empty(@val) or (some $v in tokenize(current(), '\s+') satisfies $v = @val))]">
            <xsl:attribute name="data-{name()}" select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>

    <!-- this is the added part that saves the keyref information -->
    <xsl:if test="contains(@class, ' topic/xref ') or contains(@class, ' topic/link ')">
      <xsl:if test="contains(@keyref, '.')">
        <xsl:attribute name="format" select="'html'"/>
        <xsl:attribute name="scope" select="'external'"/>
        <xsl:attribute name="href" select="concat('keyref:', @keyref)"/>
        <xsl:attribute name="data-keyref" select="@keyref"/>
      </xsl:if>
    </xsl:if>

  </xsl:template>
</xsl:stylesheet>
