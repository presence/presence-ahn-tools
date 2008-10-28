presence_agents_outbound {
  #Using Distributed Ruby we fetch the service details for CLI from the database using prefix in the extension
  begin
    service = $fetch_cli.get(extension.to_s.slice(1,3))
    ahn_log.dialplan.debug("Service returned: " + service.inspect)
  rescue => err
    ahn_log.dialplan.error(err)
    return
  end
  
  #If we find a related service than take action
  if service[:result] == 0
    case $config["assert_type"]
    when 'CALLERID'
      #Set the CallerID varaibles of the channel
      raw_response("EXEC SET CALLERID(num)=#{service[:callerid_number]}")
      raw_response("EXEC SET CALLERID(name)=#{service[:callerid_name]}")
    when 'SIPADDHEADER'
      #Add the custom SIP header P-Asserted-Identity from the last 10 characters of the Service Name
      raw_response("EXEC SipAddHeader " + 
                   "P-Asserted-Identity:" +   
                   "#{service[:callerid_name]}<sip:#{service[:callerid_number]}#{$config["from_domain"]}>")
    when 'VARIABLES'
      #Simply add 2 channel variables that may then be used in the dialplan/extensions.conf
      set_variable("ASSERTED_NAME", service[:callerid_name])
      set_variable("ASSERTED_NUMBER", service[:callerid_number])
    end
    ahn_log.dialplan.debug("Set CLI as " +
                           service[:callerid_name] + " " + 
                           service[:callerid_number])
  else
    ahn_log.dialplan.debug("Could not find a related service for #{extension}, no CLI set")
    ahn_log.dialplan.debug(service.inspect)
  end
  
  if $config["apply_variable_cli"] == TRUE
    dial_string = $config["dial_technology"] + "/" + 
                  $config["dial_prefix"].to_s +
                  extension.to_s.slice(4,extension.to_s.length) + "@" +
                  $config["dial_trunk"]
    dial(dial_string)
  end
}

pbx_click_to_call {
  #If we need to set the Variable CLI send it thorugh that context above, or dial within this context
  if $config["apply_variable_cli"] == TRUE
    +presence_agents_outbound
  else
    ahn_log.dialplan.debug("Destination to dial: " + extension.to_s)
    dial_string = $config["dial_technology"] + "/" + 
                  $config["dial_prefix"].to_s +
                  extension.to_s + '@' +
                  $config["dial_trunk"]
    dial(dial_string)
  end
}