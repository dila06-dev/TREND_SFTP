
$Credential = [System.Management.Automation.PSCredential]::new('admin',(ConvertTo-SecureString 'P@ssword1' -AsPlainText -Force))
$Body = '
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns="http://dpd.com/common/service/types/LoginService/2.0">
   <soapenv:Header/>
   <soapenv:Body>
      <ns:getAuth>
         <delisId>XXXXXX</delisId>
         <password>XXXXXX</password>
         <messageLanguage>de_DE</messageLanguage>
      </ns:getAuth>
   </soapenv:Body>
</soapenv:Envelope>
'
Invoke-WebRequest -Credential $Credential -Uri  https://esolutions.dpd.com/partnerloesungen/hazdistributionservice.aspx -Headers (@{SOAPAction='Read'}) -Method Post -Body $Body -ContentType application/xml


#Invoke-RestMethod https://esolutions.dpd.com/partnerloesungen/hazdistributionservice.aspx