rm(list=ls())
library(httr)
library(xml2)
library(jsonlite)
library(dplyr)

res2 = GET("http://transparency.entsoe.eu/api",
           query = list(documentType = 'A44', 
                        In_Domain = '10YPL-AREA-----S',
                        Out_Domain = '10YPL-AREA-----S',
                        periodStart = '202003282300',
                        periodEnd = '202003292300',
                        securityToken = '3c4152bc-42d0-4b2d-809c-3715d5d1c95d'))
http_status(res2)
XMLTree = read_xml(res2)
TimeFrame = xml_children(XMLTree)[9]
as_list(TimeFrame)

res3 = GET("http://transparency.entsoe.eu/api",
           query = list(documentType = 'A65', 
                        processType = 'A01',
                        OutBiddingZone = '10YCZ-CEPS-----N',
                        periodStart = '202003282300',
                        periodEnd = '202003302300',
                        securityToken = '3c4152bc-42d0-4b2d-809c-3715d5d1c95d'))
res3$url
res3$status_code
http_status(res3)

res4 = GET("http://transparency.entsoe.eu/api?documentType=A65&processType=A01&outBiddingZone_Domain=10YCZ-CEPS-----N&periodStart=201912312300&periodEnd=202005312300&securityToken=3c4152bc-42d0-4b2d-809c-3715d5d1c95d")
http_status(res4)
