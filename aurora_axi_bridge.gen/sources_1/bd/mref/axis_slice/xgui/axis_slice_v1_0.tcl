# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DIN_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DOUT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LOW_BIT" -parent ${Page_0}


}

proc update_PARAM_VALUE.DIN_WIDTH { PARAM_VALUE.DIN_WIDTH } {
	# Procedure called to update DIN_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DIN_WIDTH { PARAM_VALUE.DIN_WIDTH } {
	# Procedure called to validate DIN_WIDTH
	return true
}

proc update_PARAM_VALUE.DOUT_WIDTH { PARAM_VALUE.DOUT_WIDTH } {
	# Procedure called to update DOUT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DOUT_WIDTH { PARAM_VALUE.DOUT_WIDTH } {
	# Procedure called to validate DOUT_WIDTH
	return true
}

proc update_PARAM_VALUE.LOW_BIT { PARAM_VALUE.LOW_BIT } {
	# Procedure called to update LOW_BIT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LOW_BIT { PARAM_VALUE.LOW_BIT } {
	# Procedure called to validate LOW_BIT
	return true
}


proc update_MODELPARAM_VALUE.DIN_WIDTH { MODELPARAM_VALUE.DIN_WIDTH PARAM_VALUE.DIN_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DIN_WIDTH}] ${MODELPARAM_VALUE.DIN_WIDTH}
}

proc update_MODELPARAM_VALUE.LOW_BIT { MODELPARAM_VALUE.LOW_BIT PARAM_VALUE.LOW_BIT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LOW_BIT}] ${MODELPARAM_VALUE.LOW_BIT}
}

proc update_MODELPARAM_VALUE.DOUT_WIDTH { MODELPARAM_VALUE.DOUT_WIDTH PARAM_VALUE.DOUT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DOUT_WIDTH}] ${MODELPARAM_VALUE.DOUT_WIDTH}
}

