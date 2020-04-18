<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0"
                exclude-result-prefixes="xs">
  <xsl:output indent="yes"/>

  <xsl:param name="PRESERVE-KEYS" select="'no'"/>

  <xsl:template match="@xtrc"/>
  <xsl:template match="@xtrf"/>
  <xsl:template match="@class"/>
  <xsl:template match="@chunk"/>
  <xsl:template match="@copy-to"/>
  <xsl:template match="@type"/>
  <xsl:template match="bookmeta"/>
  <xsl:template match="topicmeta"/>

  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>

