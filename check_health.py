#!/usr/bin/env python
# -*- coding: utf-8 -*-


#==================================================================
#
# Copyright (C) 2020 EyesOfNetwork Team
# SUPERVISOR NAME : Jérémy HOARAU
# DEVELOPPER NAME : Oscar POELS
# VERSION : 1.0
# APPLICATION : Nagios plugin check_health
#
# LICENCE GPL2:
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#===================================================================


import os
import ssl
import sys
import yaml
import json
import logging
import requests
import argparse
import unicodedata
from requests.packages.urllib3.exceptions import InsecureRequestWarning


HELP = """
    =========================================================
       Welcome to the help page of check_api_eon.py plugin
    =========================================================

      This CLI commands allow you to interrogate EON API to 
      collect EON's services data and transmit it to your 
      Nagios server. 

"""
       

def main():
      #__________ARGUMENTS_COMMAND_LINE__________#
      parser = argparse.ArgumentParser(description=HELP, formatter_class=argparse.RawTextHelpFormatter)
      parser.add_argument("-K","--api-key", dest="api_key", help="Key given by the api after a first identification with your admin's username and password.", required=True)
      parser.add_argument("-V", "--verbose", dest="verbose", action="store_true", help="Use it for more information during the execution")
      parser.add_argument("-I","--ip-adress", dest="ip", help="Ip adress of the service you want to check", required =True)
      parser.add_argument("-U","--user", dest="user", help="Username that you want to be connected with the API", required=True)
      args = parser.parse_args()    
      
      ca_eoa = CheckApi(args)
      ca_eoa.request_to_EON_A()


class CheckApi() : 
  """
  This class Initializes the variables by default and It is this class that makes it    
  possible to carry out the http request and to transmit the information to Nagios.   
  """


  def __init__(self, args):
      logging.basicConfig(stream=sys.stderr, level=logging.INFO)
      requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
      self._args=args
      self.default_config()
      self._headers = {'content-type': 'application/json','charset':'utf-8'}
      if not self._args.verbose :
        logging.getLogger("requests").setLevel(logging.WARNING)

  def verbose(self, msg, code_error=0):
        if code_error == 0 :
            if self._args.verbose :
                logging.info(msg)

        elif code_error <= 3 and code_error > 0 : 
            logging.error(msg)
            sys.exit(code_error)
        
        else :
            logging.error("Wrong code error") 
            sys.exit(3)


  #__________FILE_CONFIG__________#
  def default_config(self):
      """
      Initialise the default variable if the command 
      line argument are not set.
      """
      if (not os.environ.get('PYTHONHTTPSVERIFY', '') and getattr(ssl, '_create_unverified_context', None)):
          ssl._create_default_https_context = ssl._create_unverified_context

  
  #__________HTTPS_REQUEST__________#
  def request_to_EON_A(self):
      """
      Entry point of the plugin execution, this function send a request to API
      and treat the json file returned.
      """


      self.verbose("Waiting a response from EON API")
      
      url="https://"+self._args.ip+"/eonapi/healthCheck?username="+self._args.user+"&apiKey="+self._args.api_key
      try:
        r = requests.api.request('get',url, verify=False, headers=self._headers)

        if r.status_code != 200 : 
          self.verbose("Requests to remote EON API failed",2)
        
        self.verbose("Treatment of the api's answer")
        self.json_treatment(r.json())
        self.verbose("========== Job complete ==========")

      except Exception,e :
          self.verbose("""An unexpected error occurred during the request to the API server.\n"""+ str(e) ,3)
    

  #_________JSON_TREATMENT__________#
  def json_treatment(self, json) : 
     
      """ 
      This function read the response of EON API 
      which is a json and process each result 
      """

      self.verbose("API's version : "+json["api_version"])
      #If http request return code is different then 200 then we exit otherwise we treat the response
      if json["http_code"].split(" ")[0] != "200":
          self.verbose("Json's response code: "+json["http_code"],1)
          sys.exit(0)
      else : 
          self.verbose("Json's response code : "+json["http_code"])
          if(json["result"][0]["disk"]["result"] == "Critical" or json["result"][1]["RAM"]["result"] == "Critical"):
            exit_sys = 2
          elif(json["result"][0]["disk"]["result"] == "Warning" or json["result"][1]["RAM"]["result"] == "Warning"):
            exit_sys = 1
          elif(json["result"][0]["disk"]["result"] == "OK" and json["result"][1]["RAM"]["result"] == "OK" ):
            exit_sys = 0
          else:
            sys.exit(3)
          print("Total space disk avaible: "+json["result"][0]["disk"]["total space disk avaible"])
          print("RAM info: "+json["result"][1]["RAM"]["RAM info"])
          print("RAM use: "+json["result"][1]["RAM"]["RAM use"])
          print("HTTPD informations: "+json["result"][2]["ports"]["HTTPD informations"])
          print("80: "+json["result"][2]["ports"]["80"])
          print("8080: "+json["result"][2]["ports"]["8080"])
          print("443: "+json["result"][2]["ports"]["443"])
          sys.exit(exit_sys)


if __name__ == '__main__':
  main()
