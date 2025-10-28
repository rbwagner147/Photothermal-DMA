#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// We need two for rvw.  For the real time values in the code and one to save along with the data. 

// Use command RheologyPanel() in the command line (ctrl+j) to make the rheology panel. 

function RheologyMasterFunction() 
	
	string DataFolder = "root:rheology"    // if path does not exist create path and initialize global variables and waves
	If (!DataFolderExists(DataFolder) )
		InitRheVarWave()	   // inital rvw to default values
	endif
	
	cd root:rheology 
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	wave /t rsw 
	
	variable err = 0 
	err =+ ir_StopPISLoop(NaN,LoopName="HeightLoop")  // stops PIDS loops if they are running (this handles case where we start off engaged) 
	if (err)
		print "Error in RheologyMasterFunction", err 
	endif 
	
	rvw[%rheFire] = 0 
		
	SetUpFilters()				// 	Sets the software filtering values
	SetUpDdsDriveARC()			// Set up DDS drive signal 
	SetUpFeedback() 				// Sets feedback to activate and deactivate on trigger

	RunApprochCTFC()   				 // Sets up CTFC and does experiment.  Follow up function calls are done as callbacks
	
	
end //RheologyMasterFunction()


function InitRheVarWave()    // initilizes rheology variable wave and rheology string wave 


	// Initalize waves (to handle case where user does not want to save everything)
	
	newdatafolder /o root:Rheology 
	cd root:Rheology
	
	make /t /o /n = 1 rsw 					// rheology string wave 
	SetDimLabel 0, 0, savePath, rsw		// subfolder to save data in 	
	rsw[%savePath] = "Data"
	
	variable Nint = 100
	make/o/n=(Nint) AppDefl, AppZsens, DriveDDS, DriveDefl, DriveAmp, DrivePha, WithDefl, WithZsens, DriveZsnr, FreqDrive, magTFc, phaTFc
	
	setscale d, 0, 10, "V", magTFc
	
	// Inital variables in global system 
	
	Wave TVW = $GetDF("Variables")+"ThermalVariablesWave"
	Wave/T TVD = Var2Desc(TVW)
	
	Wave/Z RVW = $GetDF("Variables")+"RheVariablesWave "
	if (!WaveExists(RVW))
//	if (1) 
		Duplicate/O TVW,$GetDF("Variables")+"RheVariablesWave"/Wave=RVW 
		Duplicate/O/T TVD,$GetDF("Variables")+"RheVariablesDescription"/Wave=RVWText
		Redimension/N=(0,-1) RVW,RVWText
	endif
	
	
	String PathToWave = GetWavesDataFolder(RVW,2)
	
	variable Numpts = 36 
	
	make /free /t /o /n = (Numpts) NamesList 
	NamesList[0,9] = {"rheEventCTFC","rheEventPIDS","rheEvent","rheEventPIDSoff","rheFreq","rheDeltaf","rheDriveAmp","rheDeltat","rheSetPoint","rheApprTime"}
	NamesList[10,19] = {"rheApprSpeed","rheWithDist","rheDec","rheFreqSample","rheFreqSampleLI","rheBackPack","rheFeedBack","rheRecWhat","rheLIfilter","rheAutoFS"}
	NamesList[20,29] = {"rheAutoFSLI","rheAutoLPF","rheAutoDAC","rheFire","rheApprSpeed_um","rheWithDist_um","rheScount","rheLogSpace","rheSaveCheck","rheSaveDisk"}
	NamesList[30,35] = {"rheDriveType","rheAvgTSdata","rheAvgLIdata","rheAvgTSresult","rheAvgLIresult","rheVarAmp"}

	make /free /o /n = (Numpts) ValueList
	ValueList[0,9] = {21,15,23,16,500,1500,2,2,1,5}
	ValueList[10,19] = {50,5,1,25e3,1000,0,1,0,0.25e3,1}
	ValueList[20,29] = {1,1,1,0, ValueList[10]*GV("ZPiezoSens")*1e6  , ValueList[11]*GV("ZPiezoSens")*1e6 , 0 , 0 , 1 , 1}
	ValueList[30,35] = {1,0,0,0,0,0}
	make /free /o /n =  (Numpts) UnitNumList = 1
	make /free /o /n =  (Numpts) StepList
	StepList[0,9] = {1,1,1,1,1,1,1,1,0.1,0.1}
	StepList[10,19] = { 0.1 , 0.1 , 0.1 , 1 , 1 , 1 , 1 , 1 , 0.1 , 0.1}
	StepList[20,29] = {1,1,1,1,1,1,1,1,1,1}
	StepList[30,35] = {1,1,1,1,1,1}
	make /free /o /n =  (Numpts) LowerLimitList
	LowerLimitList[0,9] = {0,0,0,0,-1499.999,-499.999,0,1e-6,-10,.01}
	LowerLimitList[10,19] = {0,0,0,1e-5,1e-5,0,0,0,1e-5,0}
	LowerLimitList[20,29] = {0,0,0,0,0,0,0,0,0,0}
	LowerLimitList[30,35] = {0,0,0,0,0,0}
	make /free /o /n =  (Numpts) UpperLimitList 
	UpperLimitList[0,9] = {30,30,30,30,2e6-1500,2e5-500,10,60*60*24,10,60*60*24}
	UpperLimitList[10,19] = {1000 ,150 , 1e10 , 2e6 , 50e3 , 1 , 3 , 3 , 2e6 ,1}
	UpperLimitList[20,29] = {1 ,1 , 1 , 1 , UpperLimitList[10]*GV("ZPiezoSens")*1e6 ,  UpperLimitList[11]*GV("ZPiezoSens")*1e6 , 1e4 ,  1 , 1 ,1}
	UpperLimitList[30,35] = {1,1e6,1e6,1e6,1e6,1}
	make /free /o /n =  (Numpts) MinimumUnitsList  = 1e-12
	
	make /free /t /o /n =  (Numpts) FormatStringList  = "%.2W1P"
	make /free /t /o /n =  (Numpts) UnitsStringList  
	UnitsStringList[0,9]   = {" "," "," "," ","Hz","Hz","V","s","V","s"}
	UnitsStringList[10,19]   = {"V/s","V"," "," Hz ","Hz"," "," "," ","Hz"," "}
	UnitsStringList[20,29]   = {" "," "," ","  ","um","um"," "," "," "," "}
	UnitsStringList[30,35]   = {" "," "," "," "," "," "}
	make /free /t /o /n =  (Numpts) DescritpionList
	DescritpionList[0,9] = {"event for CTFC","event to turn on PIDS"," event to do rheology","event to turn off PIDS","drive frequency","sweep frequency","drive amplitude","drive time","trigger value for approch curve","time given for approch"}
	DescritpionList[10,19] = {"CTFC Approch speed","CTFC Withdraw speed"," Decimation Value","Time series sampling frequency","Lock-in sampling frequency","Use backpack?","Which Feedback?","Save What?","LI filter","Auto set sampling frequency?"}
	DescritpionList[20,29] = {"Auto set LI sampling frequency?","Auto set LI LPF?"," Auto set DAC?","Did rhe fire?","Approch speed (um/s)","Withdraw Distance (um)","Subfolder counter","Log space?","Save to memory?","Save to disk?"}
	DescritpionList[30,35] = {" ","Moving average TS data","Moving average LI data","Moving average TS result","Moving Average LI result","Variable Drive Amplitude"}
//	make /free /t /o /n =  (Numpts) TitleList   = {"eventCTFC"}
	make /free /t /o /n =  (Numpts) PanelList   = "Rheology Panel"
	
	variable i = 0 
	for (i=0;i<numpnts(NamesList);i+=1)
		String StringToAdd = NamesList[i]
		Variable DidAdd = ARAddParm(StringToAdd,PathToWave,"Scansize")
		if (DidAdd)
//		if (1)
			PV(StringToAdd,ValueList[i])					// Value 
			PVU(StringToAdd,UnitNumList[i])				// Units number 
			PVS(StringToAdd,StepList[i])					// Step 
			PVL(StringToAdd,LowerLimitList[i]) 				// Lower limit 
			PVH(StringToAdd,UpperLimitList[i]) 			// Upper limit 
			PVMU(StringToAdd,MinimumUnitsList)			// Minimum units 		

			PFS(StringToAdd,FormatStringList[i])			// Format string 
			PUS(StringToAdd,UnitsStringList[i])				// Units string 
			PDS(StringToAdd,DescritpionList[i])				// Descritpion 
			PTS(StringToAdd,NamesList[i])					// Title 
			PPS(StringToAdd,PanelList[i])   				// Panel
		
		endif
	endfor 
end 


	
end 

function SetUpFilters()   // sets the various filter values 
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"	
	variable filterValue = 4*max((rvw[%rhefreq] + rvw[%rhedeltaf]),rvw[%rhefreq])    // lets set filter to 4 times the max frequency 
	
	if (filterValue > 500e3)     // 500 kHz is highest posible filter frequencies on the backpack (25 is highest on ARC... but we are not setting the ARC values).  Note:  There is a 150 kHz firmware filter in the backpack. 
		filterValue = 500e3
	endif 
	
	if (filtervalue < 5e3)			// lets not set the filter too low!
		filterValue = 5e3
	endif 
	
//	make /free /n = 3 SaveFilterWave      // Save the inital filter values.  We might need them later? 
//	SAveFilterWave[0] = GV("Cypher.Input.FastA.Filter.Freq")
//	SAveFilterWave[1] = GV("Cypher.Input.FastB.Filter.Freq")
//	SAveFilterWave[2] = GV("FBFilterBW")


	//FilterBoxFunc("ForceFilterBox", 0)     // this locks and unlocks the lock on the real time filter panel
	
	variable err = 0 
	
	PVH("Cypher.Input.FastA.Filter.Freq", 500e3)    // Sets the upper limit of the value in global list
	PV("Cypher.Input.FastA.Filter.Freq", filterValue)       // Set the value in the global list (this does not change the acutal value)
	err+= td_wv("Cypher.Input.FastA.Filter.Freq",filterValue)    // Sets the actual value

	PVH("Cypher.Input.FastB.Filter.Freq", 500e3)    
	PV("Cypher.Input.FastB.Filter.Freq", filterValue)  
	err+= td_wv("Cypher.Input.FastB.Filter.Freq",filterValue)    
	
	PVH("FBFilterBW",500e3)
	PV("FBFilterBW",filterValue)
	
	PV("Lockin.0.Filter.Freq",rvw[%rheLIfilter])
	err+= td_wv("ARC.Lockin.0.Filter.Freq",rvw[%rheLIfilter])
	
	if (err)
		print "Error in SetUpFilters()", err
	endif 
	
	return(err)
	
end  //SetUpFilters()


function SetUpDdsDriveARC()
	// This function use the DDS on the ARC to send the drive signal.  
	// The sampling frequency and number of points limitions should be less proabmatic
	// than sending the chirp signal directly with an outWave
	// If sweep then signal goes linearly from freq to freq + deltaf   (maybe add log latter)
	// Use deltaf = 0 to do sin wave 
	
	cd root:Rheology 
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	
	variable Fdsp = 50e3   							// DSP sampling frequency on the ARC
	variable Npts 									//Number of frequency points to use in freq drive wave.  
	variable dec = rvw[%rhedeltat]*Fdsp/85000    			// Choose smallest possible decimation (limited to 87,000 pts in outwave)
	rvw[%rhedec] = ceil(dec)                        				// Decimation must be an interger.  
	Npts = rvw[%rhedeltat]*Fdsp/rvw[%rhedec]                 		// Choose Number of points such that we have the right time given the decimation value. 

//	make /o /n = (Npts) FreqDriveWave	
	wave TempFreq = makefreqwave(Npts)
	duplicate /o TempFreq, FreqDriveWave
	
	variable err = 0		
	err += td_wv("Arc.lockin.0.amp",0) 				// Make sure drive amplitude is zero at start
	
	
	if (err)
		print "Error in SetUpDdsDriveARC()", err
	endif
	
	return(err)
		
end  // SetUpDdsDriveARC()

function /wave makefreqwave(Npts)    // makes the frequency drive wave
	variable Npts
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	
	make /free /o /n = (Npts) TempFreq
//	make /o /n = (5) FreqDriveWave
	setscale x, 0, rvw[%rhedeltat], "s", TempFreq 
	setscale d 0, 2e6, "Hz", TempFreq 
	if (rvw[%rhelogspace]!=1)
		TempFreq = rvw[%rhefreq] + x/rvw[%rhedeltat]*rvw[%rhedeltaf] 
	else
		variable a = ( log(rvw[%rhedeltaf]+rvw[%rhefreq]) - log(rvw[%rhefreq]) )/rvw[%rhedeltat]
		variable b = log(rvw[%rhefreq])
		TempFreq = 10^(a*x+b) 
	endif

	return TempFreq
end

function SetUpFeedback()
	
//	return(0)
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	
	Variable WhichLoop = 2

	Struct ARFeedbackStruct FB
	

	if (rvw[%rhefeedback] == 1)
		ARGetFeedbackParms(FB,"Zsensor")
	elseif (rvw[%rhefeedback] == 2)
		ARGetFeedbackParms(FB,"Height")
	else
		ARGetFeedbackParms(FB,"Height")
		FB.IGain = 0 
	endif 
	
	FB.DontSwapToBackPack = 1 // Stay on ARC
	FB.StartEvent = num2str(rvw[%rheeventPIDS])
	FB.StopEvent = num2str(rvw[%rheeventPIDSoff])
	
	String PIDSWaves = InitPIDSloopWaves()
	Wave/T PIDSloopWave = $StringFromList(0,PIDSWaves,";")
	
	
	PIDSLoopWave[%InputChannel][WhichLoop] = FB.Input
	PIDSLoopWave[%OutputChannel][WhichLoop] = FB.Output
	if (isNan(FB.Setpoint))
		PIDSLoopWave[%DynamicSetpoint][WhichLoop] = "Yes"
		PIDSLoopWave[%SetPoint][WhichLoop] = "NaN"
	else
		PIDSLoopWave[%DynamicSetpoint][WhichLoop] = "No"
		PIDSLoopWave[%SetPoint][WhichLoop] = num2str(FB.Setpoint)
	endif
	//PIDSLoopWave[%DynamicSetpoint][WhichLoop] = StringFromList(FB.DynamicSetpoint,"No;Yes;",";")
	PIDSLoopWave[%SetpointOffset][WhichLoop] = num2str(FB.SetpointOffset)
	PIDSLoopWave[%DGain][WhichLoop] = num2str(FB.DGain)
	PIDSLoopWave[%PGain][WhichLoop] = num2str(FB.PGain)
	PIDSLoopWave[%IGain][WhichLoop] = num2str(FB.IGain)
	PIDSLoopWave[%SGain][WhichLoop] = num2str(FB.SGain)
	PIDSLoopWave[%OutputMin][WhichLoop] = num2str(FB.OutputMin)
	PIDSLoopWave[%OutputMax][WhichLoop] = num2str(FB.OutputMax)
	PIDSLoopWave[%StartEvent][WhichLoop] = FB.StartEvent
	PIDSLoopWave[%StopEvent][WhichLoop] = FB.StopEvent
	PIDSLoopWave[%Status][WhichLoop] = "0"
	SetDimLabel 1,WhichLoop,$FB.LoopName,PIDSLoopWave
	
	//	ARFBWave2Struct(FB,PIDSLoopWave,A,LoopName=LoopName)
		
	String ErrorStr = ""
	ErrorStr += IR_WritePIDSloop(FB)
	ARReportError(ErrorStr)


end  // SetUpFeedback()


function RunApprochCTFC()
	// 2016-10-13 Approaches the sample, in permanence, prior to performing rheology exp
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	
	// Using ARC controller, switch to contact mode.
	//TunePanelPopupFunc("TuneLockInPopup_3",1,"ARC")
	//	MainPopupFunc("ImagingModePopup_0", 1, "Contact")
	
	td_wv("Arc.lockin.0.amp",0) // Make sure drive is zero


	//variable setPoint = 1 //TSP[0][%DC0]/FMXparm[%invOLS] + FMXparm[%farDefl_V]
	PV("DeflectionSetpointVolts",  rvw[%rhesetpoint])
	//print "\tEngaging to surface with a CTFC with setpoint "+num2str(rvw[%rheSetPoint])+" V" //(deflection = "+num2str(TSP[0][%DC0])+" nm)."

	// finally approach the surface
	make/free/T CTFC // complex triggered force curve
	variable err = td_rg("CTFC", CTFC)
	CTFC[%RampChannel] = "Output.Z" //"Height"
	CTFC[%RampOffset1] =  "160" //num2str(TSP[0][%DC0]*2+10 + FMXparm[%farDefl_V]*FMXparm[%invOLS])	// approach the max distance possible that is roughly 2x the DC setpoint
	CTFC[%RampSlope1] = num2str(rvw[%rheapprspeed]) //"100"	// V/s, determines speed of approach
	CTFC[%RampOffset2] = "0"	// do not retract
	CTFC[%RampSlope2] = "0"	// V/s
	CTFC[%EventRamp] = "3"
	CTFC[%TriggerChannel1] = "Deflection"
	CTFC[%TriggerType1] = "Relative Start"
	CTFC[%TriggerValue1] = num2str(rvw[%rhesetpoint])
	CTFC[%TriggerCompare1] = ">="
	CTFC[%TriggerChannel2] = "Output.Dummy"
	CTFC[%DwellTime1] = "0.1"		// Give the CTFC a short dwell to enable sending trigger.
	CTFC[%DwellTime2] = "0"
	



	CTFC[%Callback] = "CheckForRheTrig()"
	CTFC[%EventDwell] = num2str(rvw[%rheeventPIDS])
	CTFC[%EventEnable] = num2str(rvw[%rheeventCTFC])
	
	err += td_wg("CTFC", CTFC)

	
	variable dec = 50
	variable apprN = rvw[%rheapprTime]*50e3/dec
	make/o/n=(apprN) AppDefl, AppZsens
	AppDefl = NaN
	AppZsens = NaN
		
	
	err += td_stopInWaveBank(1)
	
	if (rvw[%rhebackpack] == 1)		
		err += td_xSetInWavePair(1, num2str(rvw[%rheeventCTFC]), "Deflection", AppDefl,"Zsensor", AppZsens,"doRheologyBP()",dec)		// Uses the backpack for time sereis capture.  Callback has latency issue. 
	else
		err += td_xSetInWavePair(1, num2str(rvw[%rheeventCTFC]), "Deflection", AppDefl,"Zsensor", AppZsens,"doRheologyARC()",dec)		// Uses the ARC for time series capture
		//err += td_xSetInWavePair(1, num2str(rvw[%rheEventCTFC]), "Deflection", AppDefl,"Zsensor", AppZsens,"",dec)		// Uses the ARC for time series capture
	endif 
	
	err += td_ws("Events.Once", num2str(rvw[%rheeventCTFC]))

	if (err) 
		print "Error in RunApprochCTFC().", err
	endif
	
	// callback for rheology experiments fires after inwaves are done recording 

end  // RunApprochCTFC()


function CheckForRheTrig()    // check to make sure we got to the trigger point before doing rheology

	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	
	if(rvw[%rheFire] == 1)
		print "It looks like the rheology experiment fired before the force curve triggered.  Try increasing the approch time." 
	endif 

end


function doRheologyARC()

	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	wave FreqDriveWave = root:rheology:FreqDriveWave

	rvw[%rheFire] = 1

	variable freqDSP = 50e3
	variable dec = ceil(freqDSP/rvw[%rhefreqsample])
	variable decLI = ceil(freqDSP/rvw[%rhefreqsampleLI])
	
	variable Npts = rvw[%rhedeltat]*freqDSP/dec
	variable NptsLI = rvw[%rhedeltat]*freqDSP/decLI
		
	make /o /n = (NptsLI) DriveZsnr, DriveFreq 

	variable err = 0 
	
	err += td_wv("Arc.lockin.0.freq",rvw[%rhefreq])			// set frequency to starting frequency  
	
	// Hack for doing a variable drive amplitude. 
	// Set root:packages:MFP3d:main:Variables:RheVariablesWave[%rheVarAmp] = 1 
	// Make a wave called AmpDriveWave in the rheology folder
	// AmpDriveWave should have [sweeptime * 50e3  /  ceil( sweeptime *50e3/85000  )] points 
	
	if (rvw[%rheVarAmp]==1)
		wave AmpDriveWave
		if (numpnts(AmpDriveWave) != numpnts(FreqDriveWave))
			print "Number of points in AmpDriveWave must equal number of points in FreqDriveWave"
			return(0)
		endif 
		err += td_wv("Arc.lockin.0.amp",AmpDriveWave[0])     // set drive amplitude to starting value		
		err += td_StopOutWaveBank(0)	
		err += td_xSetOutWavePair(0, num2str(rvw[%rheevent]) + ", Never", "ARC.Lockin.0.Freq", FreqDriveWave, "ARC.Lockin.0.Amp",AmpDriveWave, -rvw[%rhedec])
	else 	
		err += td_wv("Arc.lockin.0.amp",rvw[%rhedriveamp])     // set drive amplitude 		
		err += td_StopOutWaveBank(0)	
		err += td_xSetOutWave(0, num2str(rvw[%rheevent]) + ", Never", "ARC.Lockin.0.Freq", FreqDriveWave, -rvw[%rhedec])
	endif
	
	
	if (rvw[%rherecwhat] ==  0 || rvw[%rherecwhat] == 1)
		make /o /n = (Npts) DriveDDS 
		make /o /n=  (Npts) DriveDefl		
		err += td_stopInWaveBank(1)
		err += td_xSetInWavePair(1, num2str(rvw[%rheevent]) + ", Never", "Deflection", DriveDefl,"Cypher.Input.FastB", DriveDDS,"",dec)		//  This works becuase of data pipes. 
	endif 
	
	if (rvw[%rherecwhat] == 0 ||  rvw[%rherecwhat] == 2)
		make /o /n = (NptsLI) DriveAmp 			
		make /o /n = (NptsLI) DrivePha 
		setscale d, -180, 180, "deg", DrivePha
		err += td_stopInWaveBank(2)
		err += td_xSetInWavePair(2, num2str(rvw[%rheevent]) + ", Never" , "Amplitude" , DriveAmp , "Phase", DrivePha, "" , decLI)
	endif 
	
	err += td_stopInWaveBank(0)
	err += td_xsetinwave (0, num2str(rvw[%rheevent]) + ", Never" , "Zsensor" , DriveZsnr , "RunWithdrawCTFC()" , decLI)
//	err += td_xSetInWavePair(2, num2str(rvw[%RHEevent]) + ", Never" , "Zsensor" , DriveZsnr , "Phase", DriveFreq, "" , decLI)
	
	err += td_ws("Events.Once", num2str(rvw[%rheevent]))
	
	
	
	if (err)
		print "Error in doRheologyARC(): ", err
	endif

	// Is there a way to make the DDS start at zero?   Does not matter as we start the DDS a bit before we start recording to aviod transients. 

end  // doRheologyARC()


function doRheologyBP()    // This uses fast DACs and debug streams to record time series.  Drive signal is still sent from ARC.  Amp and Phase are still recorded on ARC.

	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	wave FreqDriveWave = root:rheology:FreqDriveWave
	
	rvw[%rheFire] = 1

	variable freqDSP = 50e3
	variable dec = ceil(freqDSP/rvw[%rhefreqsample])
	variable decLI = ceil(freqDSP/rvw[%rhefreqsampleLI])

	
	variable Npts = rvw[%rhedeltat]*freqDSP/dec
	variable NptsLI = rvw[%rhedeltat]*freqDSP/decLI
		
	make /o /n = (NptsLI) DriveZsnr 

	variable err = 0 
	
	// In and Out waves on ARC
	
	err += td_wv("Arc.lockin.0.freq",rvw[%rhefreq])			// set frequency to starting frequency (need to aviod system response) 
	
	if (rvw[%rheVarAmp]==1)
		wave AmpDriveWave
		if (numpnts(AmpDriveWave) != numpnts(FreqDriveWave))
			print "Number of points in AmpDriveWave must equal number of points in FreqDriveWave"
			return(0)
		endif 
		err += td_wv("Arc.lockin.0.amp",AmpDriveWave[0])     // set drive amplitude to starting value		
		err += td_StopOutWaveBank(0)	
		err += td_xSetOutWavePair(0, num2str(rvw[%rheevent]) + ", Never", "ARC.Lockin.0.Freq", FreqDriveWave, "ARC.Lockin.0.Amp",AmpDriveWave, -rvw[%rhedec])
	else 	
		err += td_wv("Arc.lockin.0.amp",rvw[%rhedriveamp])     // set drive amplitude 		
		err += td_StopOutWaveBank(0)	
		err += td_xSetOutWave(0, num2str(rvw[%rheevent]) + ", Never", "ARC.Lockin.0.Freq", FreqDriveWave, -rvw[%rhedec])
	endif
	
//	err += td_stopInWaveBank(1)
//	err += td_xSetInWavePair(1, num2str(rvw[%RHEevent]) + ", Never", "Deflection", DriveDefl,"UserIn0", DriveDDS,"RunWithdrawCTFC()",dec)		// Using aliases.
	
	if (rvw[%rheRecWhat] ==  0 || rvw[%rheRecWhat] == 2)
		make /o /n = (NptsLI) DriveAmp 
		make /o /n = (NptsLI) DrivePha
		setscale d, -180, 180, "deg", DrivePha
		err += td_stopInWaveBank(2)
		err += td_xSetInWavePair(2, num2str(rvw[%RHEevent]) + ", Never" , "Amplitude" , DriveAmp , "Phase", DrivePha, "" , decLI)
	endif 
	
	err += td_stopInWaveBank(0)
	err += td_xsetinwave (0, num2str(rvw[%RHEevent]) + ", Never" , "Zsensor" , DriveZsnr , "RunWithdrawCTFC()" , decLI)
	
	
	// Debug Streams stuff on Backpack 
	
	if (rvw[%rheRecWhat] ==  0 || rvw[%rheRecWhat] == 1)	
		string freqActs
		variable freqAct 
		if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
			freqActs = "500 kHz"
			freqAct = 500e3
		else
			freqActs = "2 MHz"
			freqAct = 2e6
		endif
	
		variable NptsBP =  rvw[%rheDeltat]*freqAct
		
		make /o /n=  (NptsBP) DriveDefl
		make /o /n = (NptsBP) DriveDDS 
	
		err += td_StopStream("Cypher.Stream.0")   // Kills active stream 

		// Set steam parameters 
		err += td_WS("Cypher.Stream.0.Channel.0", "Input.FastA")	 
		err += td_WS("Cypher.Stream.0.Channel.1","Input.FastB")	
		err += td_WS("Cypher.Stream.0.Rate", freqActs)	  						// Sets sample frequency (500 kHz or 2 MHz are the only options)
		err += td_WS("Cypher.Stream.0.Events",num2str(rvw[%RHEevent]) )	     // Sets up event.  Streams record data when the event is called.

		// Sets up waves to read 
		err += td_DebugStream("Cypher.Stream.0.Channel.0", DriveDefl, "")
		err += td_DebugStream("Cypher.Stream.0.Channel.1", DriveDDS, "")

		// Finish stream setup 
		err += td_SetupStream("Cypher.Stream.0")
	
	endif
	
	
	err += td_ws("Events.Once", num2str(rvw[%RHEevent]))
		
	
	if (err)
		print "Error in doRheologyBP(): ", err
	endif
	
	return(err)
	
end  // doRheologyBP()



function  RunWithdrawCTFC()    

	wave rvw = $GetDF("Variables")+"RheVariablesWave"

	variable err = 0
	err += td_wv("Arc.lockin.0.amp",0)
	
//	make /free PIDSLoop
//	err += td_rg("PIDSLoop.2", PIDSLoop)
//	PIDSLoop[%StopEvent] = rvw[%rheEventPIDSoff]
//	err += td_setupgroup("ARC.PIDSloop.2",PIDSLoop)

	err += td_ws("Events.Once", num2str(rvw[%rheEventPIDSoff]))			
	
	//doScanFunc("StopEngageButton")
	//sleep/s 1
	
	make/free/T CTFC // complex triggered force curve

	err += td_rg("CTFC", CTFC)
	CTFC[%RampChannel] = "Output.Z" //"Height"
	CTFC[%RampOffset1] =  "1" // do not approch  
	CTFC[%RampSlope1] = num2str(rvw[%rheApprSpeed]) 
	CTFC[%EventRamp] = "3"
	CTFC[%TriggerChannel1] = "Output.z"
	CTFC[%TriggerType1] = "Relative Max"
	CTFC[%TriggerValue1] = ".1"
	CTFC[%TriggerCompare1] = ">="


	CTFC[%TriggerChannel2] = "Output.dummy"
	CTFC[%RampOffset2] = num2str(-rvw[%rheWithDist])	// Max Withdraw distance
	CTFC[%RampSlope2] = num2str(-rvw[%rheApprSpeed])	// retraction speed V/s
	//CTFC[%TriggerType2] = "Relative Ramp Start"
	CTFC[%TriggerType2] = "Absolute"
	CTFC[%TriggerValue2] = "1"
	CTFC[%TriggerCompare2] = ">="


	CTFC[%Callback] = "" 
	CTFC[%DwellTime1] = "0"		
	CTFC[%DwellTime2] = "0"
	
	CTFC[%EventEnable] = num2str(rvw[%rheEventCTFC])
	
	err += td_wg("CTFC", CTFC)

	variable withTime = rvw[%rheWithDist]/rvw[%rheApprSpeed]
	
	variable dec = 50
	variable apprN = withTime*50e3/dec
	make/o/n=(apprN) WithDefl, WithZsens
	WithDefl = NaN
	WithZsens = NaN		
	
	err += td_stopInWaveBank(1)
	err += td_xSetInWavePair(1, num2str(rvw[%rheEventCTFC]), "Deflection", WithDefl,"Zsensor", WithZsens,"FinishRheologyExp()",dec)		// Using aliases.  This is a bit wasteful of time as we wait until inwaves finishes even though we may already be done withdrawing. 

	err += td_ws("Events.Once", num2str(rvw[%rheEventCTFC]))			
	
	if (rvw[%rheBackPack]==1)
		err += td_StopStream("Cypher.Stream.0")   // Makes sure streams are shut down now that we are done with them
	endif 
	
	if (err)
		print "Error in RunWithdrawCTFC()", err
	endif 
	return(err)				
	
end  // RunWithdrawCTFC()      




function FinishRheologyExp()

	cd root:rheology 
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	wave AppZsens, AppDefl    													// Approch curve 
	wave DriveDefl, DriveDDS, DriveAmp, DrivePha, DriveZsnr, FreqDriveWave			// rheology experiment 
	wave WithZsens, 	WithDefl														// Withdraw curve 

	DrivePha = - DrivePha

	variable n1 = dimsize(DriveAmp,0)
	variable n2 = dimsize(FreqDriveWave,0)

//	duplicate /free DriveZsnr, Raw, FreqDrive
	
//	duplicate /o DriveZsnr, FreqDrive
//	FreqDrive = rvw[%rheFreq] + x/rvw[%rheDeltat]*rvw[%rheDeltaf]    // Recaulate frequency wave to match spacing and points of captured data.  Assumes lienar ramp.  Not perfect... but good enough for now. 
//	setscale y, wavemin(FreqDrive), wavemax(FreqDrive), "Hz", FreqDrive

	wave TempFreq = makefreqwave(n1)     // Make a frequency drive wave with the same number of points as Driveamp for plotting purposes. 
	duplicate /o TempFreq, FreqDrive
	
//	duplicate /o FreqDriveWave, FreqDrive
//	variable nr = n2/n1 
//	resample /down = (nr) FreqDrive     // This is be slightly wrong.  Try to thing of a better approch later.  (Can't upsample and then downsample to get the exact right number because most genearl case is too large)
//	Redimension /n=(n1) FreqDrive
	
//	duplicate /free DriveDefl, TimeWave 
//	Ax2Wave(DriveDefl,0,TimeWave)
//	ARSaveAsForce(1,"SaveForce","DeflV;In0;AmpV;Phase;Freq;Time", Raw, DriveDefl, DriveDDS, DriveAmp, DrivePha, FreqDrive, TimeWave,CustomNote = "TestNote")
	
	// Clean up the events and shut stuff down
	
	variable err = 0
	err += td_ws("Arc.CTFC.EventDwell","Never")
	err += td_ws("Arc.CTFC.EventRamp","Never")
	err += td_ws("Arc.CTFC.EventEnable","Never")
	err += td_stopgroup("Arc.PIDSLoop.2")
	err += td_ws("Arc.PIDSLoop.2.StartEvent","Never")
	err += td_ws("Arc.PIDSLoop.2.StopEvent","Never")
	
	// Set the filter values back to something resonable for scanning

	variable filterValue = 5e3 
	PV("Cypher.Input.FastA.Filter.Freq", filterValue)       // Set the value in the global list (this does not change the acutal value)
	err+= td_wv("Cypher.Input.FastA.Filter.Freq",filterValue)    // Sets the actual value
	PV("Cypher.Input.FastB.Filter.Freq", filterValue)  
	err+= td_wv("Cypher.Input.FastB.Filter.Freq",filterValue)    
	PV("FBFilterBW",filterValue)
	
	if (err)
		print "Error in SaveRheologyExp()", err
	endif 

	
	// That should be everthing.  Debug streams was shut down elsewhere.  
	// Save and plot data.  Also compare time sereis to lock-in with an FFT 
		
	plotRheology()  	// Plot last experiment 
	rheFFT()		// Computes FFT of time series data
	rheAmpComp()	// Plots FFT and compares it with Lock In values
//	if (rvw[%rheSaveCheck] == 1)
	saveRheology() 	// Saves last experiment based on save settings 
//	endif 


	ARCallbackFunc("ForceDone")    // Highjack the force curve callback (for macrobuilder)
				
	print "Rheology Exp Done!"   // can we make it clear that the system is still doing stuff before this runs?


end  // FinishRheologyExp()



function plotRheology([FileName])
	
	string FileName 
	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)

	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	wave AppZsens, AppDefl    													// Approch curve 
	wave DriveDefl, DriveDDS, DriveAmp, DrivePha, DriveZsnr, FreqDrive 			// rheology experiment 
	wave WithZsens, 	WithDefl														// Withdraw curve 

	DoWindow /f RheologyDAta 
	if (V_flag == 1)
		GetWindow RheologyData wsizeRM
		DoWindow /k RheologyData   
		Display /N=RheologyData /W=(V_left,V_top,V_right,V_bottom) as "Rheology Data" // note '/N=' flag
	else
		DoWindow /k RheologyData   
		Display /N=RheologyData /W=(50,50,1050,550) as "Rheology Data" // note '/N=' flag
	endif 
	
	Display /host = RheologyData  /W=(.01,.01,.33,.5) /N=AppDefl AppDefl 
	Label left "Approch Deflection (\\U)"	
	Label bottom "Time (\\U)"
	Display /host = RheologyData  /W=(.01,.51,.33,.99) /N=AppZsens AppZsens
	Label left "Approch Zsensor (\\U)"
	Label bottom "Time (\\U)"
	
	Display /host = RheologyData  /W=(.34,.01,.66,.25) /n=DriveDefl DriveDefl
	Label left "Deflection (\\U)"	
	Label bottom "Time (\\U)"
	Display /host = RheologyData  /W=(.34,.26,.66,.5) /n=DriveDDS DriveDDS
	Label left "Drive (\\U)"	
	Label bottom "Time (\\U)"
	Display /host = RheologyData  /W=(.34,.51,.66,.75) /n=DriveAmp DriveAmp
	Label left "Amplitude (\\U)"	
	Label bottom "Time (\\U)"
	Display /host = RheologyData  /W=(.34,.76,.66,.99) /n=DrivePha DrivePha
	Label left "Phase (\\U)"
	Label bottom "Time (\\U)"
	
	Display /host = RheologyData /W=(.67,.01,.99,.5)  /n = WithDefl WithDefl
	Label left "Withdraw Deflection (\\U)"
	Label bottom "Time (\\U)"
	Display /host = RheologyData  /W=(.67,.51,.99,.99) /n = WithZsens WithZsens
	Label left "Withdraw Zsensor (\\U)"
	Label bottom "Time (\\U)"
//	else
//		setactivesubwindow RheologyData#AppDefl
//		SetAxis /A
//		setactivesubwindow RheologyData#AppZsens
//		SetAxis /A
//		
//		setactivesubwindow RheologyData#DriveDefl
//		SetAxis /A
//		setactivesubwindow RheologyData#DriveDDS
//		SetAxis /A
//		setactivesubwindow RheologyData#DriveAmp
//		SetAxis /A
//		setactivesubwindow RheologyData#DrivePha
//		SetAxis /A
//		
//		setactivesubwindow RheologyData#WithDefl
//		SetAxis /A
//		setactivesubwindow RheologyData#WithZsens
//		SetAxis /A
// 	endif 



end  // plotRheology()


function rheFFT([FileName])    // Calculates amplitude and phase relative to drive of time series data.  Crops ampltidue and phase when drive signal is less than 1/4 its maximum

	string FileName 
	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
		
	wave RS = DriveDefl 
	wave RD = DriveDDS 
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
		
	variable fstart, fstop 
	
	fstart = min(rvw[%rheFreq],rvw[%rheFreq]+rvw[%rheDeltaf]) - 0.01*min(rvw[%rheFreq],rvw[%rheFreq]+rvw[%rheDeltaf])
	fstop = max(rvw[%rheFreq],rvw[%rheFreq]+rvw[%rheDeltaf]) + 0.01*max(rvw[%rheFreq],rvw[%rheFreq]+rvw[%rheDeltaf])

	extract /free /o RS, RSnoNan, (numtype(RS)==0 || numtype(RD)==0)   // gets rid of any nan values before doing FFT.  I don't know why we sometimes see Nan values in these waves. 
	extract /free /o RD, RDnoNan, (numtype(RD)==0 || numtype(RS)==0)
	
	setscale /P  x, 0, DimDelta(RS, 0 ), RSnoNan    // Sets the wave scaling.  This only works at if the nan values are at the end of the wave. 
	setscale /P  x, 0, DimDelta(RD, 0 ), RDnoNan
	
	// might want to put some logic here than gives warning if middle of the wave has Nan values.

//	extract /o RS, RSnoNan, (numtype(RS)==0 || numtype(RD)==0)
//	extract /o RD, RDnoNan, (numtype(RD)==0 || numtype(RS)==0)

	if ( numpnts(RS) != numpnts(RSnoNan))
		print "Warning:  There are some Nan points in the time series data.  These were deleted to do the FFT analysis"
	endif

	variable Npnts_RS = numpnts(RSnoNan)	
//	variable Npnts_RD = numpnts(RDnoNan)
	
	if (Npnts_RS/2 != floor(Npnts_RS/2))
		deletepoints (Npnts_RS-2), 1, RSnoNan, RDnoNan
	endif

	fft /dest = fftsamp RSnoNan
	fft /dest = fftDrive RDnoNan


//	fft /dest = fftsamp RS
//	fft /dest = fftDrive RD 
	
	duplicate /free /o /C fftsamp, fftTF 

	fftTF = fftsamp/fftDrive      // Compute transfer funciton.  This handles normilzation. 
	
	make /free /o /n = (numpnts(fftTF))	 magTF, phaTF, magD, phaD, freqTF
//	make /o /n = (numpnts(fftTF))	 magTF, phaTF, magD, phaD, freqTF
	setscale x, 0, DimDelta(fftTF, 0 )*dimsize(fftTF,0), "Hz", magTF, phaTF, magD, phaD, freqTF
	setscale d, -180, 180, "deg", phaTF, phaD
	setscale d, 0, 10, "V", magTF, magD
	
	freqTF = x 

	magTF = sqrt(real(fftTF)^2+imag(fftTF)^2) 
	phaTF = -180/pi*atan2(imag(fftTF), real(fftTF))
	
	magD = sqrt(real(fftDrive)^2+imag(fftDrive)^2) 
	phaD = -180/pi*atan2(imag(fftDrive), real(fftDrive))
	
//	display magTF
//	display phaTF
	
	variable nstart, nstop, Pmax, Phalf 
	
// crop based on set frequncy range 
		
	variable i, npts 
	npts = numpnts(magD)
	nstart = 0 
	nstop = npts-1
	for (i=0;i<npts;i+=1)
//		if (magD[i] > Phalf)
		if (freqTF[i] > fstart)
			nstart = i
			break 
		endif 
	endfor
	 
	 for(i=0;i<npts;i+=1)
//	 	if (magD[npts-1-i] > Phalf)
		if (freqTF[i] > fstop)
	 		nstop =i
	 		break 
 		endif 
	endfor 
	 
 	Pmax = wavemax(magD ,freqTF[nstart],freqTF[nstop])
	Phalf = .5*Pmax

// crop based on magnitude of the bias signal
	
	if (rvw[%rheDeltaf]==0) 
		for (i=nstart;i<nstop;i+=1)
			if (magD[i] == Pmax)	
				nstart = i
				nstop = i 
				break 
			endif 
		endfor

	else
		 	 
//		for (i=nstart;i<nstop;i+=1)				// This is suppose to addjust the frequency range of the FFT based on max power... however because of 1/f stuff this is not very reliable.  Kill it for now.
//			if (magD[i] > Phalf)	
//				nstart = i
//				break 
//			endif 
//		endfor
//	 
//		 for(i=nstart;i<nstop;i+=1)
//		 	if (magD[i] < Phalf)
//		 		nstop = i-1
//		 		break 
// 			endif 
//		endfor 
	endif 
	
	// grab subranges 
	
	 duplicate /r = [nstart, nstop] /o magTF, magTFc
	 duplicate /r = [nstart, nstop] /o phaTF, phaTFc

	 
	 magTFc = magTFc*rvw[%rheDriveAmp]			// Multiply by drive amplitude.   This puts the units back to volts of PD signal. 
	 

	killwaves fftsamp, fftDrive				// These wave are intermediate values.  Kill them to get them from cluttering the experiment.
		
	cd root:rheology
	
end //rheFFT()  


function rheAmpComp([FileName])    // makes a plot that compares lock-in data to times series FFT data 
	string FileName 
	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	wave magTFc, phaTFc, FreqDrive, DriveAmp, DrivePha
	
	if (rvw[%rheAvgTSdata])
		rhesmoothxy(magTFc,phaTFc,rvw[%rheAvgTSdata])
	endif
	
	if (rvw[%rheAvgLIdata])
		rhesmoothxy(DriveAmp,DrivePha,rvw[%rheAvgLIdata])
	endif
	
//	smooth 5, magTFc

	
	DoWindow /f AmpComp
	if (V_flag == 1)
		GetWindow AmpComp wsizeRM
		DoWindow /k AmpComp   
		Display /N=AmpComp /W=(V_left,V_top,V_right,V_bottom) as "Rheology Data" // note '/N=' flag
	else
		DoWindow /k AmpComp   
		Display /N=AmpComp /W=(50,50,550,550) as "Rheology Data" // note '/N=' flag
	endif 
	
	Display /host = AmpComp  /W=(.01,.01,.99,.5)  /N=Mag magTFc
	Label left "Amplitude (\\U)"
	Label bottom "Frequency (\\U)"
	appendtograph /W=AmpComp#Mag DriveAmp vs FreqDrive
	ModifyGraph rgb(magTFc)=(0,15872,65280)
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
	
	Display /host = AmpComp  /W=(.01,.51,.99,.99)  /N=Pha phaTFc
	Label bottom "Frequency (\\U)"
	Label left "Phase (\\U)"
	appendtograph /W=AmpComp#Pha DrivePha vs FreqDrive
	ModifyGraph rgb(phaTFc)=(0,15872,65280)	 	
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif

	
	 Legend/C/N=text0/J/A=RT "\\s(phaTFc) FFT of Time Series\r\\s(DrivePha) Locki-n"

	cd root:rheology
	
end


function saveRheology()     // This saves all the waves in the experiment to a subfolder specified by the user.  There are proablly better ways of doing this.  Revist later. 

		
	cd root:rheology 
	wave /t rsw 
	wave rv = $GetDF("Variables")+"RheVariablesWave" 																	// List of rheology variables 

	
	string nameStr = rsw[%savePath] + Num2StrLen(rv[%rheScount],4)
	
	wave AZ = AppZsens 
	wave AD = AppDefl    													// Approch curve 

	wave RD = DriveDefl 
	wave RS = DriveDDS 
	wave RA = DriveAmp 
	wave RP = DrivePha
	wave RZ =  DriveZsnr
	wave RF =  FreqDrive			// rheology experiment 

	wave WZ = WithZsens 	
	wave WD = WithDefl														// Withdraw curve 
	
	
	wave TFA = magTFc					// FFT of time sereis
	wave TFP = phaTFc

	if (rv[%rheSaveCheck] == 1 )

		newdatafolder /o $nameStr
		cd $nameStr
		
		duplicate /o, AZ, AppZsens
		duplicate /o, AD, AppDefl
		duplicate /o, RD, DriveDefl
		duplicate /o, RS, DriveDDS
		duplicate /o, RA, DriveAmp
		duplicate /o, RP, DrivePha
		duplicate /o, RZ, DriveZsnr
		duplicate /o, RF, FreqDrive
		duplicate /o, WZ, WithZsens
		duplicate /o, WD, WithDefl
		duplicate /o, TFA, magTFc
		duplicate /o, TFP, phaTFc
		
		duplicate /o, rv, rvw
	
		Notify(rvw)    // Add note with other global variables to rvw
		
	endif 
		
	if (rvw[%rheSaveDisk] == 1)
				
		Notify(rv)    // Add note with other global variables to rvw
		
		string pathstr = GS("SaveImage") + nameStr
		
		newpath /c/o rhesavepath, pathstr
		
//		newdatafolder /o $nameStr
//		cd $nameStr
		
		save /c/o /p=rhesavepath AZ as "AppZsens.ibw"
		save /c/o /p=rhesavepath AD as "AppDefl.ibw"
		save /c/o /p=rhesavepath RD as "DriveDefl.ibw"
		save /c/o /p=rhesavepath RS as "DriveDDS.ibw"
		save /c/o /p=rhesavepath RA as "DriveAmp.ibw"
		save /c/o /p=rhesavepath RP as "DrivePha.ibw"
		save /c/o /p=rhesavepath RZ as "DriveZsnr.ibw"
		save /c/o /p=rhesavepath RF as "FreqDrive.ibw"
		save /c/o /p=rhesavepath WZ as "WithZsens.ibw"
		save /c/o /p=rhesavepath WD as "WithDefl.ibw"
		save /c/o /p=rhesavepath TFA as "magTFc.ibw"
		save /c/o /p=rhesavepath TFP as "phaTFc.ibw"
		
		save /c/o /p=rhesavepath rv as "rvw.ibw"
			
		
	endif
	
	cd root:rheology
	
	if (rv[%rheSaveCheck] == 1 || rv[%rheSaveDisk] == 1)	
		rv[%rheScount] += 1    //  Increase the save counter
		ControlUpdate /w=Rheology /a    // update panel	
	endif 


end 

Function Notify(Data)
	Wave Data

	Wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	Wave GVW = root:Packages:MFP3D:Main:Variables:GeneralVariablesWave
	Wave/T RVD = root:Packages:MFP3D:Main:Variables:RealVariablesDescription
	Wave NapVW = root:Packages:MFP3D:Main:Variables:NapVariablesWave
	Wave XPTwave = root:Packages:MFP3D:XPT:XPTLoad
	Wave CVW = root:Packages:MFP3D:Main:Variables:ChannelVariablesWave
	Wave NCVW = root:Packages:MFP3D:Main:Variables:NapChannelVariablesWave
	Wave TVW = root:Packages:MFP3D:Main:Variables:ThermalVariablesWave
	Wave LVW = root:Packages:MFP3D:Main:Variables:LithoVariablesWave
	Wave UserParmWave = root:Packages:MFP3D:Main:Variables:UserVariablesWave
	Wave FilterVW = root:Packages:MFP3D:Main:Variables:FilterVariablesWave

	String NoteStr = ""
		NoteStr += GetWaveParms(MVW)							//this puts the master variable wave parms in the note
		NoteStr += GetwaveParms(NapVW)
		NoteStr += GetWaveParms(CVW)							//this puts the channel variable wave parms in the note
		NoteStr += GetWaveParms(XPTwave)						//grab the crosspoint setup
		NoteStr += GetWaveParms(FilterVW)
		NoteStr += GetWaveParms(TVW)
		NoteStr += GetWaveParms(UserParmWave)
		
		
	Note/K Data
	Note Data,NoteStr
	
End //


function loadrheology()


	//  Get load folder from user 

	cd root:rheology
  	String messageSt = " File Path? "
   	NewPath /M=messageSt/O rheloadpath  
  	if (V_flag)
  		print "Canceled Load!"
  		return(0)
	endif 
	
	// Get string from symbolic load path 
	
	pathinfo rheloadpath	
	   string  pathstr = S_path
      
   // parse strings 
   
   string foldername = ParseFilePath(0, pathstr, ":", 1, 0)	    // gets the name of the rheology folder
	string pathstrlist = IndexedFile(rheloadpath,-1,".ibw")
	variable numlist = itemsinlist (pathstrlist) 
	
	// load data 
	
	cd root:rheology
	newdatafolder /o/s $foldername
	
	variable i
	for (i=0;i<numlist;i+=1)
		string tempstr = pathstr + stringfromlist(i,pathstrlist)		
		LoadWave /o tempstr
	endfor
	
	
	cd root:rheology

end 

function rheExportFunc([filename])   // exports all waves in filename to disk 
	string filename 

	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists " + FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
		
//	string nameStr =  
	string pathstr = GS("SaveImage") + filename		
	newpath /c/o rhesavepath, pathstr
		
	string wavestr = WaveList("*",";","")
	Save /O /C /B /p=rhesavepath wavestr

end 

//// Rheology Panel Stuff /////


Menu "Rheology"
	"Open Rheology Panel", RheologyPanel()
End


window RheologyPanel() : Panel  //built ftrom the GUI panel in Kiracofe's CR mod
	PauseUpdate; Silent 1		// building window...
	DoWindow/F Rheology
	
	if (V_flag == 0) 
	
		//	NewPanel/K=1 /W=(175,96,650,435) /N=Rheology
		NewPanel/K=1 /W=(275,96,750,465) /N=Rheology
	
		string DataFolder = "root:rheology"    // if path does not exist create it and initialize global variables
		If (!DataFolderExists(DataFolder))
			InitRheVarWave()	   // inital rvw to default values
		endif
	
		TabControl tb, tabLabel(0)="Controls", size={475,390}, proc = RheTabProc
		TabControl tb, tabLabel(1)="Data Acquisition", proc = RheTabProc
		TabControl tb, tabLabel(2)="Data Analysis", proc = RheTabProc
		TabControl tb, tabLabel(3)="Contact Mechanics", proc = RheTabProc


	
		//	cd root:rheology 
		//	wave rvw = root:packages:MFP3D:Main:Variables:RheVariablesWave
	
		GroupBox ChirpControls, pos = {15,25}, size = {220,265}, title = "Chirp Controls"
		SetVariable Freq,pos={25,50},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheFreq],title="Start Frequency (Hz)"
		SetVariable deltaf,pos={25,100},size={200,15}, proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheDeltaf] ,title="Sweep Frequency (Hz)"
		SetVariable driveamp,pos={25,150},size={200,15}, proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheDriveAmp] ,title="Drive Amplitude (V)"
		SetVariable detlat,pos={25,200},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheDeltat] ,title="Sweep Time (s)"
		checkbox logspace, pos={25,250}, proc = RheCheckBox, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheLogSpace], title = "Logarithmic Sweep"
	
		GroupBox FZControls, pos = {240,25}, size = {220,275}, title = "Force Distance Controls"
		SetVariable setpoint,pos={250,50},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheSetPoint],title="Trigger Point (V)"
		SetVariable apprTime,pos={250,100},size={200,15}, proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheApprTime] ,title="Approach Time (s)"
		//	SetVariable apprspeed,pos={250,150},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheApprSpeed] ,title="Approach Speed (V/s)"
		//	SetVariable withdist,pos={250,200},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheWithDist] ,title="Withdraw Distance (V)"
		SetVariable apprspeed,pos={250,150},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheApprSpeed_um] ,title="Approach Speed (um/s)"
		SetVariable withdist,pos={250,200},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheWithDist_um] ,title="Withdraw Distance (um)"

		PopupMenu Feedback, pos={250,250},size={200,15}, proc = RhePopupFunc, value="Zsensor;Deflection;None", title ="Dwell Feedback" 

		Button doRheExp, pos={25,300},size={150,30}, proc = RheButtonFunc, title = "Do Experiment"

	
		//	GroupBox DAQControls, pos = {15,25}, size = {300,300}, title = "Data Acquisition Settings", disable = 1
		GroupBox DAQControls, pos = {15,40}, size = {350,320}, disable = 1
		SetVariable freqsample,pos={25,50},size={200,15},proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheFreqSample] ,title="Time Series Sampling (Hz)", disable = 1
		SetVariable tsavg, pos={25,90}, size={200,15}, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheAvgTSdata], title="Time Series Moving Average", disable = 1
		SetVariable freqsampleLI,pos={25,130},size={200,15}, proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheFreqSampleLI] ,title="Lockin Sampling (Hz)", disable = 1
		SetVariable liavg, pos={25,170}, size={200,15}, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheAvgLIdata], title="Lockin Moving Average", disable = 1
		SetVariable freqlockin,pos={25,210},size={200,15}, proc = RheSetVarFunc, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheLIfilter] ,title="Lockin LPF (Hz)", disable = 1
		PopupMenu DAC, pos={25,250},size={200,15}, proc = RhePopupFunc, value="ARC;BackPack", title="Which ADCs", disable = 1
		PopupMenu DataType, pos={25,290},size={200,15}, proc = RhePopupFunc, value="Everything;Time Series;Lockin", title = "Data Channels" 	, disable = 1
		SetVariable saveName,pos={25,330},size={185,15},value = root:rheology:rsw[%savePath] ,title="SubFolder", disable = 1
		SetVariable saveCount, pos={215,330}, size={95,15}, value = root:packages:MFP3D:Main:Variables:RheVariablesWave[%rheScount], title="Index", disable = 1


		checkbox saveCheck, pos = {235,280}, proc = RheCheckBox, title ="Save to Memory", value=1, disable = 1
		checkbox saveDisk, pos = {235,300}, proc = RheCheckBox, title ="Save to Disk", value=0, disable = 1
	
		checkbox autoFs, pos = {235,50}, proc = RheCheckBox, title ="Auto Set", value=1, disable = 1
		checkbox autoFsLI, pos = {235,130}, proc = RheCheckBox, title ="Auto Set", value=1, disable = 1
		checkbox autoLPF, pos = {235,210}, proc = RheCheckBox, title ="Auto Set", value=1, disable = 1
		checkbox autoACD, pos = {235,250}, proc = RheCheckBox, title ="Auto Set", value=1, disable = 1
	

		// analysis tab
	
		string DataFolder2 = "root:rheology:analysis"    
		If (!DataFolderExists(DataFolder2) )
			newdatafolder /o root:Rheology:analysis
		endif
	
		cd root:rheology:analysis  

		getRheDataList()
		//	wave /t filelist 
		make /o /n = (dimsize(filelist,0)) filesel 
	
		make /o /t samplist ={""}
		make /o /n = (dimsize(samplist,0)) sampsel
	
		make /o /t reflist ={""}
		make /o /n = (dimsize(reflist,0)) refsel
		
		//	listbox testlist, pos = {15,25}, size = {220,265}, listWave = filelist, mode = 4, title = "testListtest" 
		listbox filelist, pos = {15,25}, size = {120,180}, mode = 4, selWave = filesel, listWave = filelist , title = "testListtest" , disable = 1
		listbox samplist, pos = {150,25}, size = {120,180}, mode = 0, selWave = sampsel, listWave = samplist , title = "testListtest" , disable = 1
		listbox reflist, pos = {285,25}, size = {120,180}, mode = 0, selWave = refsel, listWave = reflist , title = "testListtest" , disable = 1

		button reset, pos = {15,215}, size = {120,30}, proc = RheAnaButtonFunc, title = "Reset", disable = 1
		button movetosamp, pos = {150,215}, size = {120,30}, proc = RheAnaButtonFunc, title = "Move to Sample", disable = 1
		button movetoref , pos = {285,215}, size = {120,30}, proc = RheAnaButtonFunc, title = "Move to Reference", disable = 1
	
		button doanalysis , pos = {285,305}, size = {120,30}, proc = RheAnaButtonFunc, title = "Do Analysis", disable = 1
		button viewdata , pos = {150,260}, size = {120,30}, proc = RheAnaButtonFunc, title = "View Data", disable = 1
		button getnotes , pos = {15,260}, size = {120,30}, proc = RheAnaButtonFunc, title = "View Notes", disable = 1
	
		button dataload , pos = {15,305}, size = {120,30}, proc = RheAnaButtonFunc, title = "Load Data", disable = 1
		button datasave , pos = {150,305}, size = {120,30}, proc = RheAnaButtonFunc, title = "Save Data", disable = 1

	
		string /g analysistype = "Peizo;Direct;"
		PopupMenu drivetype, pos={285,260},size={120,30}, value=#"root:rheology:analysis:analysistype", title="Analysis Type", disable = 1

		// Contact mechanics tab

		//	TabControl subtbcm, tabLabel(0)="JRK", size={475,390}, pos = {0,30}, proc = RheCMTabProc, disable = 1    // Start of sub tab setup for mutliple cotnact mechanics models.  I am not too sure to to best handel this.  Revist later. 
		//	TabControl subtbcm, tabLabel(1)="DMT", proc = RheCMTabProc, disable = 1

		variable /g tipradius = 10 
		variable /g poissonsratio = 0.3
		SetVariable nu, pos={25,290}, size={200,15}, value=root:rheology:analysis:poissonsratio, title="Possion's ratio", disable = 1
		SetVariable rad,pos={25,260},size={200,15}, value=root:rheology:analysis:tipradius,title="Tip Radius (nm)", disable = 1
		button JRKcalc , pos = {15,320}, size = {120,30}, proc = RheAnaButtonFunc, title = "JRK Modulus", disable = 1


		cd root:rheology
	
		ControlUpdate /w=Rheology /a
	
	endif

	
end


Function RheTabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca
	switch (tca.eventCode)
		case 2: // Mouse up
			Variable tabNum = tca.tab // Active tab number
			Variable isTab0 = tabNum==0
			Variable isTab1 = tabNum==1
			Variable isTab2 = tabNum==2
			Variable isTab3 = tabNum==3

			
			ModifyControl ChirpControls disable=!isTab0 // Hide if not Tab 0
			ModifyControl Freq disable=!isTab0 
			ModifyControl deltaf disable=!isTab0
			ModifyControl driveamp disable=!isTab0 
			ModifyControl detlat disable=!isTab0
			
			ModifyControl FZControls disable=!isTab0 // Hide if not Tab 0
			ModifyControl setpoint disable=!isTab0 
			ModifyControl apprTime disable=!isTab0
			ModifyControl apprspeed disable=!isTab0 
			ModifyControl withdist disable=!isTab0
			ModifyControl Feedback disable=!isTab0
			ModifyControl logspace disable=!isTab0
			
			ModifyControl doRheExp disable=!isTab0
			
			ModifyControl DAQControls disable=!isTab1 // Hide if not Tab 1
			ModifyControl freqsample disable=!isTab1 
			ModifyControl freqsampleLI disable=!isTab1 
			ModifyControl freqlockin disable=!isTab1 
			ModifyControl DAC disable=!isTab1 
			ModifyControl DataType disable=!isTab1 
			ModifyControl saveName disable=!isTab1 
			ModifyControl saveCount disable=!isTab1 
			ModifyControl saveCheck disable=!isTab1 
			ModifyControl saveDisk disable=!isTab1 
			
			ModifyControl tsavg disable=!isTab1 
			ModifyControl liavg disable=!isTab1 
			
			

			
			ModifyControl autoFs disable=!isTab1 
			ModifyControl autoFsLI disable=!isTab1 
			ModifyControl autoLPF disable=!isTab1 
			ModifyControl autoACD disable=!isTab1			
			
			ModifyControl filelist disable=(!isTab2 && !isTab3)
			ModifyControl samplist disable=(!isTab2 && !isTab3)
			ModifyControl reflist disable=(!isTab2 && !isTab3)

			ModifyControl reset disable=(!isTab2 && !isTab3)
			ModifyControl movetosamp disable=(!isTab2 && !isTab3)
			ModifyControl movetoref disable=(!isTab2 && !isTab3)
	
			ModifyControl doanalysis disable=!isTab2 
			ModifyControl viewdata disable=!isTab2 
			ModifyControl getnotes disable=!isTab2 
			ModifyControl drivetype disable=!isTab2 
			ModifyControl dataload disable=!isTab2 
			ModifyControl datasave disable=!isTab2 
			
//			ModifyControl subtbcm disable=!isTab3 

			ModifyControl nu disable=!isTab3
			ModifyControl rad disable=!isTab3

			ModifyControl JRKcalc disable =!isTab3

			
		break
	endswitch
	return 0
End

function RhePopupFunc(ctrlName,popNum,popStr) : PopupMenuControl
	
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
	variable freqDSP = 50e3
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"

	if(stringmatch(ctrlName, "DAC"))     // switch the DAC.  Also if switch DAC set sampling frequency to an allowable value. 
		if (popNum == 1)
			rvw[%rheBackPack] = 0 
			rvw[%rheFreqSample] = freqDSP/ceil(freqDSP/rvw[%rheFreqSample])			
				
		elseif (popNum == 2)
			rvw[%rheBackPack] = 1 
			if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
				rvw[%rheFreqSample] = 500e3
			else
				rvw[%rheFreqSample] = 2000e3
			endif 
		endif 		 		
		
	endif 
	
	if(stringmatch(ctrlName, "Feedback"))
		if (popNum == 1)
			rvw[%rheFeedBack] = 1 
		elseif (popNum == 2)
			rvw[%rheFeedBack] = 2
		elseif  (popNum == 3)
			rvw[%rheFeedBack] = 0			
		endif 
	endif 
	
	if(stringmatch(ctrlName, "DataType"))
		if (popNum == 1)
			rvw[%rheRecWhat] = 0 
		elseif (popNum == 2)
			rvw[%rheRecWhat] = 1
		elseif  (popNum == 3)
			rvw[%rheRecWhat] = 2			
		endif 
	endif 
	
	
	ControlUpdate /w=Rheology /a
	
end 


function RheCheckBox(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selected, 0 if not
	
	variable freqDSP = 50e3
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	
	
	StrSwitch (ctrlName)
		case "autoFs":
			rvw[%rheAutoFS] = checked 
			
			if (checked)
				rvw[%rheFreqSample] = 10*max((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])
				if(rvw[%rheBackPack]==1)
					if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
						rvw[%rheFreqSample] = 500e3
					else
						rvw[%rheFreqSample] = 2000e3
					endif 										
				else
					rvw[%rheFreqSample] = freqDSP/ceil(freqDSP/rvw[%rheFreqSample])
				endif 	
			endif 
			
			break 
		case "autoFsLI":
			rvw[%rheAutoFSLI] = checked 
			
			if (checked)
				rvw[%rheFreqSampleLI] = 5000/rvw[%rheDeltat]			// Hz
				rvw[%rheFreqSampleLI] = freqDSP/ceil(freqDSP/rvw[%rheFreqSampleLI])
			endif
			
			break 
		case "autoLPF":
			rvw[%rheAutoLPF] = checked 
				if (checked)
				rvw[%rheLIfilter] = min((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])/2
				
				if(rvw[%rheLIfilter] > 2000)    
					rvw[%rheLIfilter] = 2000
				endif
				
			endif 
			break 
		case "autoACD":
			rvw[%rheAutoDAC] = checked
			
			if(checked)				
				if(rvw[%rheFreq]+rvw[%rheDeltaf] > 7e3)
					rvw[%rheBackPack] = 1
					//RhePopupFunc("DAC",2,"BackPack")
				else 
					rvw[%rheBackPack] = 0
				endif 								
				
				rvw[%rheFreqSample] = 10*max((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])
				if(rvw[%rheBackPack]==1)
					if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
						rvw[%rheFreqSample] = 500e3
					else
						rvw[%rheFreqSample] = 2000e3
					endif 										
				else
					rvw[%rheFreqSample] = freqDSP/ceil(freqDSP/rvw[%rheFreqSample])
				endif
				
			endif 
		
			break
			
		case "logspace" : 
			rvw[%rheLogSpace] = checked			
			break 
		
		case "saveCheck": 
			rvw[%rheSaveCheck] = checked
			break 

		case "saveDisk": 
			rvw[%rheSaveDisk] = checked
			break 
			
	endswitch
	
	
End


function RheSetVarFunc(ctrlName,varNum,varStr,varName)  : SetVariableControl   // Should maybe use a stucture for this 
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	wave rvw = $GetDF("Variables")+"RheVariablesWave"
	variable freqDSP = 50e3
	
	
	variable dec = ceil(freqDSP/rvw[%rheFreqSample])
	variable decLI = ceil(freqDSP/rvw[%rheFreqSampleLI])
	
	variable Npts = rvw[%rheDeltat]*freqDSP/dec
	
	
	// This sets limits on what can be input into the panel based on various settings.  This is a mess.  I am sorry. 
	// This also sets the data aquistions settings based on the drive frequencies if the checkbox's are checked
	// Might not want to have lockin filter set to auto adjust by default (could create some odd data)
	
	// Up arrow for sampling frequency don't work... need to fix 	
	// Popup menu for ADC does not switch when we change value in wave .... need to fix 
	
	StrSwitch (ctrlName)
		case "Freq":    // Don't send 0 or negative frequency to the lockin.  Guess sampling frequency, LI LPF, and which DAC to use if asked to by user. 
		
			if(rvw[%rheFreq] <= 0)  
				rvw[%rheFreq] = 0.01 
			endif 
			
			if(rvw[%rheFreq]+rvw[%rheDeltaf] <= 0)
				rvw[%rheDeltaf] = -rvw[%rheFreq] + 0.01
			endif 
			
						

			if(rvw[%rheAutoDAC]==1)				
				if(rvw[%rheFreq]+rvw[%rheDeltaf] > 7e3)
					//rvw[%rheBackPack] = 1
					RhePopupFunc("DAC",2,"BackPack")
				else 
					rvw[%rheBackPack] = 0
				endif 								
			endif 
			
			if(rvw[%rheAutoFS]==1)				
				rvw[%rheFreqSample] = 10*max((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])
				if(rvw[%rheBackPack]==1)
					if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
						rvw[%rheFreqSample] = 500e3
					else
						rvw[%rheFreqSample] = 2000e3
					endif 										
				else
					rvw[%rheFreqSample] = freqDSP/ceil(freqDSP/rvw[%rheFreqSample])
				endif 				
			endif
			
			if (rvw[%rheAutoLPF] == 1)
				rvw[%rheLIfilter] = min((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])/2
				if(rvw[%rheLIfilter] > 2000)    // Don't think that we need to set this to high
					rvw[%rheLIfilter] = 2000
				endif
			endif 
			
			break 
			
		case "deltaf":    // Don't send 0 or negative frequency to the lockin.  Guess sampling frequency, LI LFP and which DAC to use if asked to by user. 

			if(rvw[%rheFreq]+rvw[%rheDeltaf] <= 0)
				rvw[%rheDeltaf] = -rvw[%rheFreq] + 0.01
			endif 
			
			if(rvw[%rheAutoDAC]==1)				
				if(rvw[%rheFreq]+rvw[%rheDeltaf] > 7e3)
					rvw[%rheBackPack] = 1
					//RhePopupFunc("DAC",2,"BackPack")
				else 
					rvw[%rheBackPack] = 0
				endif 								
			endif 
			
			if(rvw[%rheAutoFS]==1)				
				rvw[%rheFreqSample] = 10*max((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])
				if(rvw[%rheBackPack]==1)
					if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
						rvw[%rheFreqSample] = 500e3
					else
						rvw[%rheFreqSample] = 2000e3
					endif 										
				else
					rvw[%rheFreqSample] = freqDSP/ceil(freqDSP/rvw[%rheFreqSample])
				endif 				
			endif 			
			
			if (rvw[%rheAutoLPF] == 1)
				rvw[%rheLIfilter] = min((rvw[%rheFreq]+rvw[%rheDeltaf]),rvw[%rheFreq])/2
				
				if(rvw[%rheLIfilter] > 2000)    
					rvw[%rheLIfilter] = 2000
				endif
				
			endif 
		
			break
			
		case "driveamp": 	   // Drive amp should be between 0 and 10 V for the outputs we are using (10 V is max DDS amplitude?) 
			
			if (rvw[%rheDriveAmp] < 0)
				rvw[%rheDriveAmp] = 0
			elseif(rvw[%rheDriveAmp] > 10)
				rvw[%rheDriveAmp] = 10 
			endif
			
			break 
					
		case "detlat":     // Time must be positive.  Also guess lockin sampling rate based on measurment time if asked to. 
		
			if (rvw[%rheDeltat]<=0)
				rvw[%rheDeltat] = 1e-6 
			endif 
			
			if (rvw[%rheAutoFSLI] == 1)
				rvw[%rheFreqSampleLI] = 5000/rvw[%rheDeltat]			// Hz
				rvw[%rheFreqSampleLI] = freqDSP/ceil(freqDSP/rvw[%rheFreqSampleLI])
			endif 
			
			break 

		case "freqsample":   // Freqsample must be 50e3/n (where n is a postive interger) on ARC or 500 kHz or 2 MHz on backpack. 
			
			if(rvw[%rheBackPack]==1)
				if ( abs(rvw[%rheFreqSample] -500e3)  <  abs(rvw[%rheFreqSample] -2000e3) )
					rvw[%rheFreqSample] = 500e3
				else
					rvw[%rheFreqSample] = 2000e3
				endif 										
			else
				rvw[%rheFreqSample] = freqDSP/ceil(freqDSP/rvw[%rheFreqSample])
			endif
			
			break 
			
		case "freqsampleLI":  // FreqsampleLI must be 50e3/n (where n is a postive interger) 
			
			rvw[%rheFreqSampleLI] = freqDSP/ceil(freqDSP/rvw[%rheFreqSampleLI])
			
			break 
			
		case "freqlockin":   // Must be positive (I don't know how large numbers will act.. might want to put maximum at 25 kHz) 
		
			if (rvw[%rheLIfilter] <= 0) 
				rvw[%rheLIfilter] = 10 
			endif 

			break 
  		
  		case "apprspeed":   		  	
				rvw[%rheApprSpeed] = rvw[%rheApprSpeed_um]/(GV("ZPiezoSens")*1e6)
  		  		
  			break 
  			
  		case "withdist":
				rvw[%rheWithDist] = rvw[%rheWithDist_um]/(GV("ZPiezoSens")*1e6)
				
  			break 
  		
	endswitch
	
	ControlUpdate /w=Rheology /a

end // RheSetVarFunc


Function RheButtonFunc(controlstart) : ButtonControl
	String controlstart

	print "Rheology Experiment Running..." 
	RheologyMasterFunction() 
	
		
end	//


function RheAnaButtonFunc(controlstart) : ButtonControl
	String controlstart

	wave /t filelist = root:rheology:analysis:filelist 
	wave /t samplist = root:rheology:analysis:samplist 
	wave /t reflist =  root:rheology:analysis:reflist 
	wave filesel = root:rheology:analysis:filesel 
	wave sampsel = root:rheology:analysis:sampsel
	wave refsel = root:rheology:analysis:refsel 
	
	variable i 
	variable nfile = numpnts(filesel)
	variable nsamp = numpnts(sampsel)
	variable nref = numpnts(refsel)
	
	
	StrSwitch (controlstart)
		
		case "reset": 
			getRheDataList()
			
			Redimension /n = (1) samplist
			Redimension /n = (1) sampsel
			samplist = {""}
			
			Redimension /n = (1) reflist
			Redimension /n = (1) refsel
			reflist = {""}
			
			break 
		
		case "movetosamp": 

			for (i = 0; i<nfile; i+=1)
				if(filesel[i] == 1)
					print filelist[i]
					nsamp  =  numpnts(sampsel)
					Redimension /n = (nsamp +1) samplist
					Redimension /n = (nsamp+1) sampsel
					samplist[nsamp-1] = filelist[i] 
					
					deletepoints  i, 1, filelist 
					deletepoints  i, 1, filesel 
					
					nfile = nfile-1
					i = i - 1 

					
				endif 
			endfor 
			
			break 

		case "movetoref": 

			for (i = 0; i<nfile; i+=1)
				if(filesel[i] == 1)
					print filelist[i]
					nref  =  numpnts(refsel)
					Redimension /n = (nref +1) reflist
					Redimension /n = (nref+1) refsel
					reflist[nref-1] = filelist[i] 
					
					deletepoints  i, 1, filelist 
					deletepoints  i, 1, filesel 
					
					nfile = nfile-1
					i = i - 1 
					
				endif 
			endfor 
			break 
			
		case "doanalysis":
			
			variable drive = 1
			ControlInfo /w=rheology drivetype						
			if(stringmatch(S_value,"Direct"))
				drive = 2
			endif
			
			nsamp  =  numpnts(sampsel)-1
			nref  =  numpnts(refsel)-1

	//	string /g analysistype = "Peizo;Direct;"
	//	PopupMenu drivetype, pos={285,260},size={120,30}, value=#"root:rheology:analysis:analysistype", title="Analysis Type", disable = 1
	
			//calcRheFromRef(samplist[0],reflist[0],type=0, drive = drive)   
			
			for(i=0; i < nsamp; i+=1) 
				if (i< nref) 
					calcRheFromRef(samplist[i],reflist[i],type=0, drive = drive)  // does calc with the ith values in list 
				else 
					calcRheFromRef(samplist[i],reflist[nref-1],type=0, drive = drive)   // does calc with the ith sample and the last reference measurement
				endif 
			endfor  
			
			break 
		
		case "getnotes": 
			
			for(i=0;i<nfile;i+=1)
				if (filesel[i] == 1)
					break 
				endif 
			endfor 
			rheDispRVW(filelist[i])    // need to improve display, add other important notes, handel multiple selections 
			
			break 
			
		case "viewdata":
			
//			plotRheResult([FileName])  

			for(i=0;i<nfile;i+=1)
				if (filesel[i] == 1)
					break 
				endif 
			endfor 
			plotRheology(filename = filelist[i])    // need to improve display, add other important notes, handel multiple selections 
			
			break 
			
		case "dataload": 
		
			loadrheology()
			
			getRheDataList()
			
			Redimension /n = (1) samplist
			Redimension /n = (1) sampsel
			samplist = {""}
			
			Redimension /n = (1) reflist
			Redimension /n = (1) refsel
			reflist = {""}
		
			break 
			
		case "datasave": 
						
			variable err = 1 
			for(i=0;i<nfile;i+=1)
				if (filesel[i] == 1)
					rheExportFunc(filename = filelist[i])
//					print filelist[i]
					err = 0 
				endif 
			endfor 
			
//			for(i=0;i<nsamp;i+=1)
//				if (sampsel[i] == 1)
////					rheExportFunc(samplist[i])
//					print samplist[i]
//					err = 0 
//				endif 
//			endfor 
//			
//			for(i=0;i<nref;i+=1)
//				if (refsel[i] == 1)
////					rheExportFunc(reflist[i])
//					print reflist[i]
//					err = 0 
//				endif 
//			endfor 
			
			if (err) 
				print "Please select a file to save" 
			endif
			


			
			break 
		
		case "JRKcalc": 
			
			RheCalcModBatch()
			
			break 
				
	endswitch
	
	
	for (i = 0; i<nfile; i+=1)
		//print filelist[i]	
	endfor 

end



function getRheDataList()    // gets names of data files 
	
	
	cd root:rheology 
	string filestring = dataFolderDir(1)	
	cd root:rheology:analysis 

	
	// List of exceptions.  Do not include these values the file list 
	
	filestring = ReplaceString("FOLDERS:", filestring, "")
	filestring = ReplaceString(",analysis", filestring, "")
	filestring = ReplaceString("analysis,", filestring, "")
	filestring = ReplaceString(",,", filestring, ",")
	filestring = ReplaceString(";", filestring, "")
	filestring = ReplaceString("\r", filestring, "")

	
	// End list of exceptions

	
	Make/O/T/N=(ItemsInList(filestring, ",")) filelist
	filelist = StringFromList(p, filestring, ",")
	make /o /n = (dimsize(filelist,0)) filesel 
	
//	filelist[numpnts(filelist)-1] = ReplaceString(";", filelist[numpnts(filelist)-1], "")
	
//	print filestring 
//	print filelist
	
end





/// End Rheology Panel stuff //// 


/// Data analysis stuff /////////

function rheDispRVW(data)    // makes a table of rvw with dimison lables
	string data 
	cd root:rheology 
	cd $data
	
	wave rvw 
	variable npnts = numpnts(rvw)
	variable i 
	make /o /t /n = (npnts) rvwLabel 
	for (i=0;i<npnts;i+=1)	
		rvwLabel[i] = getdimlabel(rvw,0,i)
	endfor 
	
	DoWindow /f rvwTable	
	if (V_flag == 1)
		GetWindow rvwTable wsizeRM
		DoWindow /k rvwTable   
		edit /N=rvwTable /W=(V_left,V_top,V_right,V_bottom) rvwLabel, rvw as "Rheology Variable Wave" // note '/N=' flag
	else
		DoWindow /k rvwTable   
		edit /N=rvwTable /W=(50,50,550,550) rvwLabel, rvw as "Rheology Variable Wave" // note '/N=' flag
	endif 
	
	cd root:rheology 

end

function rhesmoothxy(A,p,n)
	wave A,p 
	variable n
	
	duplicate /free A, x, y
	x = A*cos(p*pi/180)
	y = A*sin(p*pi/180)
	
	smooth n, x, y
	
	A = sqrt(x^2+y^2)
	p = atan2(y,x)*180/pi 
	 

end 


function calcRheFromRef(samp,ref,[type, drive])    // Caluclates stiffness and loss tangent from reference measurement on a stiff sample and an uknown measurement 
	string samp, ref
	variable type, drive   
	
	if (ParamIsDefault(type))   // type is what data to process.  Lockin, time series, or both 
		type = 0 
	endif 
	
	if (ParamIsDefault(drive))   // drive is peizo dirve (1) or direct dirve (2)
		drive = 1
	endif 
	

	cd root:rheology	
	cd $ref 
	wave rvw_ref = rvw 
	string notestring_ref = note(rvw_ref) 
	variable k_ref = numberbykey("SpringConstant", notestring_ref, ":","\r",0)
	variable ols_ref = numberbykey("InvOLS", notestring_ref, ":","\r",0)
	
	wave ALI_ref = DriveAmp 
	wave PLI_ref = DrivePha
	wave ATS_ref = magTFc
	wave PTS_ref  = phaTFc	
	wave Freq_ref = FreqDrive 

	cd root:rheology
	cd $samp
	wave rvw_samp = rvw 
	string notestring_samp = note(rvw_samp)
	variable k_samp = numberbykey("SpringConstant",notestring_samp, ":","\r",0)
	variable ols_samp = numberbykey("InvOLS", notestring_samp, ":","\r",0)

	wave ALI_samp = DriveAmp 
	wave PLI_samp = DrivePha
	wave ATS_samp = magTFc
	wave PTS_samp  = phaTFc 
	wave Freq_samp = FreqDrive
	
	// Interpolate reference data such that it point spacing matches the sample data
	
	duplicate /free ALI_samp, ALI_ref_I
	duplicate /free PLI_samp, PLI_ref_I
	duplicate /free ATS_samp, ATS_ref_I
	duplicate /free PTS_samp, PTS_ref_I
	duplicate /free Freq_samp, Freq_ref_I
	duplicate /free Freq_samp, t_ref_I
	
	duplicate /free ATS_ref, x_ref
	duplicate /free ATS_samp, x_samp		
		
//	duplicate /o ALI_samp, ALI_ref_I
//	duplicate /o PLI_samp, PLI_ref_I
//	duplicate /o ATS_samp, ATS_ref_I
//	duplicate /o PTS_samp, PTS_ref_I
//	duplicate /o Freq_samp, Freq_ref_I
//	duplicate /o Freq_samp, t_ref_I
	
	t_ref_I = x 
	
//	duplicate /o ATS_ref, x_ref
//	duplicate /o ATS_samp, x_samp
	
	x_ref = x
	x_samp = x
	
	if (dimsize(ATS_ref,0) > 1) 			// Don't interpolate if there is only one data point in the FFT
		ATS_ref_I = interp(x_samp,x_ref,ATS_ref)
		PTS_ref_I = interp(x_samp,x_ref,PTS_ref)
	else 
		ATS_ref_I = ATS_ref
		PTS_ref_I = PTS_ref
	endif 
	
	duplicate /free Freq_ref, t_ref
	duplicate /free Freq_samp, t_samp
	
	t_ref = x
	t_samp = x
	
	if (dimsize(ATS_ref,0) > 1)    // Don't interpolate if there is only one data point in the FFT
		t_ref_I = interp(Freq_samp,Freq_ref,t_ref)	
		ALI_ref_I = interp(t_ref_I,t_ref,ALI_ref)
		PLI_ref_I = interp(t_ref_I,t_ref,PLI_ref)
		Freq_ref_I = interp(t_ref_I,t_ref,Freq_ref)
	else 
		t_ref_I = t_ref
		ALI_ref_I = ALI_ref
		PLI_ref_I =PLI_ref
		Freq_ref_I = Freq_ref
	endif 
//	duplicate /free PTS_ref, PTS_ref_I
	
//	interp
			
	RheCompCheck(rvw_ref,rvw_samp)  	
	
	if (1 == 1) 
	
		DoWindow /f RheologyComp
		if (V_flag == 1)	
			GetWindow RheologyComp wsizeRM
			DoWindow /k RheologyComp   
			Display /N=RheologyComp /W=(V_left,V_top,V_right,V_bottom) as "Rheology Comp" // note '/N=' flag
		else
			DoWindow /k RheologyComp   
			Display /N=RheologyComp /W=(50,50,550,550) as "Rheology Comp" // note '/N=' flag
		endif 
	
		Display /host = RheologyComp /W=(.01,.01,.99,.50)  /N=Amp ATS_samp
		Label left "Amplitude (\\U)"
		Label bottom "Frequency (\\U)"
		appendtograph /W=RheologyComp#Amp  ATS_ref
		appendtograph /W=RheologyComp#Amp ALI_samp vs Freq_samp		
		appendtograph /W=RheologyComp#Amp ALI_ref vs Freq_ref		
		ModifyGraph rgb[0]=(65280,0,0)
		ModifyGraph rgb[1]=(65280,43520,0)
		ModifyGraph rgb[2]=(0,15872,65280)
		ModifyGraph rgb[3]=(0,65280,0)
		
		if (rvw_samp[%rheLogSpace]==1)
			ModifyGraph log(bottom)=1
		endif
		
		Legend/C/N=text0/F=0/A=LT /J "\s(#0) FFT sample \r\s(#1) FFT reference\r\s(#2) LI sample\r\s(#3) LI reference"
	
		
//		SetAxis left -1*kL,20*kL
//		Legend/C/N=text0/J/H={0,2,10}/A=LT "\\s(kTSp) Time Series\r\\s(kLIp) Lock in"
	
		Display /host = RheologyComp  /W=(.01,.51,.99,.99)  /N=Pha PTS_samp
		Label bottom "Frequency (\\U)"
		Label left "Phase (\\U)"
		appendtograph /W=RheologyComp#Pha PTS_ref 
		appendtograph /W=RheologyComp#Pha PLI_samp vs Freq_samp
		appendtograph /W=RheologyComp#Pha PLI_ref vs Freq_ref
		ModifyGraph rgb[0]=(65280,0,0)
		ModifyGraph rgb[1]=(65280,43520,0)
		ModifyGraph rgb[2]=(0,15872,65280)
		ModifyGraph rgb[3]=(0,65280,0)	 	
		if (rvw_samp[%rheLogSpace]==1)
			ModifyGraph log(bottom)=1
		endif
//		SetAxis left -1*kL,20*kL



	
	
	endif 
	
	
	duplicate /o ALI_samp, kLIp, kLIpp, tandLI
	duplicate /o ATS_samp, kTSp, kTSpp, tandTS
	setscale d -100, 100, "N/m", kLIp, kLIpp, kTSp, kTSpp
	setscale d -10, 10, "", tandLI, tandTS
	
//	make /o /n = (numpnts(ALI_samp)) kLIp, kLIpp, tandLI
//	make /o /n = (numpnts(ATS_samp)) kTSp, kTSpp, tandTS
	
	
	if (drive == 2) 
	
		if (type == 0)      //   Calc values from both LI and TS
			rheStiffnessValuesD(ALI_samp,PLI_samp,ALI_ref_I,PLI_ref_I,kLIp,kLIpp,tandLI,k_samp,ols_samp,ols_ref) 
			rheStiffnessValuesD(ATS_samp,PTS_samp,ATS_ref_I,PTS_ref_I,kTSp,kTSpp,tandTS,k_samp,ols_samp,ols_ref) 
		elseif (type == 1)    // Calc only from TS
			rheStiffnessValuesD(ATS_samp,PTS_samp,ATS_ref_I,PTS_ref_I,kTSp,kTSpp,tandTS,k_samp,ols_samp,ols_ref) 
		elseif (type == 2)    // Calc only from LI 
			rheStiffnessValuesD(ALI_samp,PLI_samp,ALI_ref_I,PLI_ref_I,kLIp,kLIpp,tandLI,k_samp,ols_samp,ols_ref) 
		else
			print "Error in calcRheStiffness, bad type"
		endif 
	
	else 

		if (type == 0)      //   Calc values from both LI and TS
			rheStiffnessValues(ALI_samp,PLI_samp,ALI_ref_I,PLI_ref_I,kLIp,kLIpp,tandLI,k_samp,ols_samp,ols_ref) 
			rheStiffnessValues(ATS_samp,PTS_samp,ATS_ref_I,PTS_ref_I,kTSp,kTSpp,tandTS,k_samp,ols_samp,ols_ref) 
		elseif (type == 1)    // Calc only from TS
			rheStiffnessValues(ATS_samp,PTS_samp,ATS_ref_I,PTS_ref_I,kTSp,kTSpp,tandTS,k_samp,ols_samp,ols_ref) 
		elseif (type == 2)    // Calc only from LI 
			rheStiffnessValues(ALI_samp,PLI_samp,ALI_ref_I,PLI_ref_I,kLIp,kLIpp,tandLI,k_samp,ols_samp,ols_ref) 
		else
			print "Error in calcRheStiffness, bad type"
		endif	
		
	endif 
	
	if (1 == 1)
	
//		smooth 1000, kLIp, kLIpp, tandLI, kTSp, kTSpp, tandTS
		
	
	endif 
	
	cd root:rheology
	
	plotRheResult(FileName = samp)
	



end


function rheStiffnessValues(Acs,pha_cs,Acm,pha_cm,kp,kpp,tand,kL,cLs,cLm)      // equations for piezo excitation from Igarashi et al.  Macromolecules 2013
	wave Acs,pha_cs,Acm,pha_cm,kp,kpp,tand
	variable kL,cLs, cLm
	
//	duplicate /free Acs, Amp_s, pha_s
	duplicate /free Acs, Amp_s, pha_s
	setscale d -180, 180, "deg", pha_s
	
	Amp_s = sqrt(Acm^2+Acs^2-2*Acm*Acs*cos(pha_cs*pi/180-pha_cm*pi/180))
	pha_s = 180/pi*atan( ( Acm*sin(pha_cm*pi/180)-Acs*sin(pha_cs*pi/180) )/( Acm*cos(pha_cm*pi/180)-Acs*cos(pha_cs*pi/180) ) )
	kp = kL*Acs/Amp_s*cos(pha_cs*pi/180 - pha_s*pi/180)
	kpp = kL*Acs/Amp_s*sin(pha_cs*pi/180 - pha_s*pi/180)
	tand = kpp/kp 

end


function rheStiffnessValuesD(As,phas,A0,pha0,kp,kpp,tand,kL,cLs,cLm)      // equations for direct excitation from Prathima et al.  Soft Matter 2012
	wave As,phas,A0,pha0,kp,kpp,tand
	variable kL,cLs, cLm
	
//	duplicate /free Acs, Amp_s, pha_s
	duplicate /free As, Ab, phab
	setscale d -180, 180, "deg", phab
	
	Ab = A0/As
	phab = pha0-phas
	
//	Amp_s = sqrt(Acm^2+Acs^2-2*Acm*Acs*cos(pha_cs*pi/180-pha_cm*pi/180))
//	pha_s = 180/pi*atan( ( Acm*sin(pha_cm*pi/180)-Acs*sin(pha_cs*pi/180) )/( Acm*cos(pha_cm*pi/180)-Acs*cos(pha_cs*pi/180) ) )
	kp = kL*(Ab*cos(phab*pi/180)-1)
	kpp = kL*Ab*sin(phab*pi/180)
	tand = kpp/kp 

end


function RheCompCheck(rvw_ref,rvw_samp)  	 
	wave rvw_ref, rvw_samp	
	variable check = 1 
	
	variable fstart_ref = min(rvw_ref[%rheDeltaf]+rvw_ref[%rheFreq],rvw_ref[%rheFreq]) 
	variable fstop_ref = max(rvw_ref[%rheDeltaf]+rvw_ref[%rheFreq],rvw_ref[%rheFreq]) 

	variable fstart_samp = min(rvw_samp[%rheDeltaf]+rvw_samp[%rheFreq],rvw_samp[%rheFreq]) 
	variable fstop_samp = max(rvw_samp[%rheDeltaf]+rvw_samp[%rheFreq],rvw_samp[%rheFreq]) 
		
			
	
	if (fstart_ref > fstart_samp || fstop_ref < fstop_samp)    
		//check = 0 
		print "Warning: The frequency bandwidth of the reference measurement does not cover the entire range of the sample measurement."
		print "The code is attepting to interpolate values for the reference measurment outside of the reference measurements frequency range." 
		print "The analysis results in these regions are not correct."  
	endif 
	
//	return(check) 
	
end

function plotRheResult([FileName])     // plots the rheology results 
	
	string FileName 
	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
	
	wave rvw, kLIp, kLIpp, tandLI, kTSp, kTSpp, tandTS, FreqDrive
	
	string notestring = note(rvw)
	variable kL = numberbykey("SpringConstant",notestring, ":","\r",0)
	
	DoWindow /f RheologyResult
	if (V_flag == 1)
//		GetWindow RheologyData wsizeRM
		GetWindow RheologyResult wsizeRM
		DoWindow /k RheologyResult   
		Display /N=RheologyResult /W=(V_left,V_top,V_right,V_bottom) as "Rheology Result" // note '/N=' flag
	else
		DoWindow /k RheologyResult   
		Display /N=RheologyResult /W=(50,50,550,550) as "Rheology Result" // note '/N=' flag
	endif 
	
	
	Display /host = RheologyResult /W=(.01,.01,.99,.33)  /N=kp kTSp
	Label left "Storage Stiffness (\\U)"
	Label bottom "Frequency (\\U)"
	appendtograph /W=RheologyResult#kp kLIp vs FreqDrive
	ModifyGraph rgb(kTSp)=(0,15872,65280)
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
//	SetAxis left -1*kL,20*kL
//	SetAxis left -1, 5
	Legend/C/N=text0/J/H={0,2,10}/A=LT "\\s(kTSp) Time Series\r\\s(kLIp) Lock in"
	
	Display /host = RheologyResult  /W=(.01,.34,.99,.66)  /N=kpp kTSpp
	Label bottom "Frequency (\\U)"
	Label left "Loss Stiffness (\\U)"
	appendtograph /W=RheologyResult#kpp kLIpp vs FreqDrive
	ModifyGraph rgb(kTSpp)=(0,15872,65280)	 	
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
//	SetAxis left -1*kL,20*kL
//	SetAxis left -1, 5

	
	Display /host = RheologyResult  /W=(.01,.67,.99,.99)  /N=tand tandTS
	Label bottom "Frequency (\\U)"
	Label left "Loss Tangent"
	appendtograph /W=RheologyResult#tand tandLI vs FreqDrive
	ModifyGraph rgb(tandTS)=(0,15872,65280)	 	
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
//	SetAxis left 0, 2 



end


function plotRheMod([FileName])     // plots the rheology results 
	
	string FileName 
	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
	
	wave rvw, ELIp, ELIpp, tandLI, ETSp, ETSpp, tandTS, FreqDrive
	
	string notestring = note(rvw)
	variable kL = numberbykey("SpringConstant",notestring, ":","\r",0)
	
	DoWindow /f RheologyMod
	if (V_flag == 1)
//		GetWindow RheologyData wsizeRM
		GetWindow RheologyMod wsizeRM
		DoWindow /k RheologyMod   
		Display /N=RheologyMod /W=(V_left,V_top,V_right,V_bottom) as "Rheology Modulus" // note '/N=' flag
	else
		DoWindow /k RheologyMod   
		Display /N=RheologyMod /W=(50,50,550,550) as "Rheology Modulus" // note '/N=' flag
	endif 
	
	
	Display /host = RheologyMod /W=(.01,.01,.99,.33)  /N=kp ETSp
	Label left "Storage Modulus (\\U)"
	Label bottom "Frequency (\\U)"
	appendtograph /W=RheologyMod#kp ELIp vs FreqDrive
	ModifyGraph rgb(ETSp)=(0,15872,65280)
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
//	SetAxis left -1*kL,20*kL
//	SetAxis left -1, 5
	Legend/C/N=text0/J/H={0,2,10}/A=LT "\\s(ETSp) Time Series\r\\s(ELIp) Lock in"
	
	Display /host = RheologyMod  /W=(.01,.34,.99,.66)  /N=kpp ETSpp
	Label bottom "Frequency (\\U)"
	Label left "Loss Modulus (\\U)"
	appendtograph /W=RheologyMod#kpp ELIpp vs FreqDrive
	ModifyGraph rgb(ETSpp)=(0,15872,65280)	 	
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
//	SetAxis left -1*kL,20*kL
//	SetAxis left -1, 5

	
	Display /host = RheologyMod  /W=(.01,.67,.99,.99)  /N=tand tandTS
	Label bottom "Frequency (\\U)"
	Label left "Loss Tangent"
	appendtograph /W=RheologyMod#tand tandLI vs FreqDrive
	ModifyGraph rgb(tandTS)=(0,15872,65280)	 	
	if (rvw[%rheLogSpace]==1)
		ModifyGraph log(bottom)=1
	endif
//	SetAxis left 0, 2 



end


/// Contact mechanics calculations 

function RheCalcModBatch()
	wave /t samplist = root:rheology:analysis:samplist 
	
	nvar rad = root:rheology:analysis:tipradius 				// tip radius (nm)
	nvar	 nu = root:rheology:analysis:poissonsratio 				// Possion's ratio 
	
	variable nsamp = dimsize(samplist,0)
	
	if (nsamp == 1) 
		print "Please move the data you would like to analyze to the sample list" 
	endif 
	
	variable i 
	for (i = 0; i<nsamp-1;i+=1)
		print " " 
		print samplist[i]
//		print i 
		RheCalcModMasterFunc(rad,nu,filename=samplist[i])
		plotRheMod(FileName=samplist[i])   
	endfor
		
end


function RheCalcModMasterFunc(rad,nu,[filename])
	variable rad, nu	

	string filename 
	
	if(ParamIsDefault(filename))  
		filename = "" 
	endif 
	
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
		

	wave AppZsens, AppDefl, WithZsens, WithDefl  
	
	wavestats /q WithDefl 
	variable with_min_index = V_minRowLoc
		
	variable Favg_V = AppDefl[dimsize(AppDefl,0)-1]
	variable Fadh_V = wavemin(WithDefl) 
	variable Foff_V = AppDefl[0]

	
	
	variable Zcont_V = WithZsens[with_min_index]			
	
	// Find withdraw zero force index.  If starting value is zero use starting index (might be better logic here.... assumes peak force is positive) 
	variable numloops 
	variable with_zero_index =0 
	if  (Favg_V-Foff_V > 0 )
		numloops = dimsize(WithDefl,0)
		for (with_zero_index=0;with_zero_index<numloops-1;with_zero_index+=1)
			if (WithDefl[with_zero_index]-Foff_V<0)
				break 
			endif 
		endfor
	endif 		
	variable Zzero_V = WithZsens[with_zero_index]

//	variable Favg_V = 0.0408
//	variable Fadh_V = -.415
//	variable Foff_V = 0.0625
	
//	variable Zcont_V = 1.365
//	variable Zzero_V = 1.812 
		
			
	
	
	wave rvw 
	
	string notestr = note(rvw)
	
	variable kL = numberbykey("SpringConstant", notestr, ":","\r",0)			// nN/nm
	variable cL = numberbykey("InvOLS", notestr, ":","\r",0)*1e9				// nm/V
	variable Zsens = numberbykey("ZLVDTSens", notestr, ":","\r",0)*1e9		// nm/V
	
	print "kL (nN/nm) = ", kL
	print "cL (nm/V) = ", cL
	print "Zsens (nm/V) = ", Zsens
	
	variable force = (Favg_V-Foff_V)*cL*kL
	variable force_adh = -(Fadh_V-Foff_V)*cL*kL
	variable ind = (Zzero_V-Zcont_V)*Zsens + (Fadh_V-Foff_V)*cL

	wave kTSp 
	wave kTSpp 	
	duplicate /o kTSp ETSp 
	duplicate /o kTSpp ETSpp 
	
	wave kLIp 
	wave kLIpp 	
	duplicate /o kLIp ELIp 
	duplicate /o kLIpp ELIpp 
	setscale d, 0, 0, "Pa", ELIp, ELIpp, ETSp, ETSpp

	
	RheCalcModJKR(kTSp,kTSpp,ETSp,ETSpp,nu,force,force_adh,ind,rad)
	RheCalcModJKR(kLIp,kLIpp,ELIp,ELIpp,nu,force,force_adh,ind,rad)


end

function RheCalcModJKR(kp,kpp,Ep,Epp,nu,force,force_adh,ind,rad)
	wave kp, kpp, Ep, Epp     						// storage stiffness, loss stiffness, storage modulus, loss modulus 
	variable nu,force, force_adh, rad, ind			// Poisson's ratio, Average Force (nN), Adhesive Force (nN), tip radius (nm), relative indentation between zero point and contact point (nm) 
	
	
	variable a1 = RheJKRcontactArea(force,force_adh,ind,rad)	   			// contact area at average force (nm)
	variable a0 = RheJKRcontactArea(-force_adh,force_adh,ind,rad)	   	// contact area at point where force = force_adh (nm)
	
	print "a_avg (nm) = ", a1 
	print "a_contact (nm) = ", a0
	print "nu = ", nu
	print "F_avg (nN) = ", force
	print "F_adh (nN) = ", force_adh
	print "r (nm) = ", rad
	print "delta ind (nm) =", ind
	
	Ep = (1-nu^2) / (2*a1) * (1-1/6*(a0/a1)^(3/2) ) / (1-(a0/a1)^(3/2) ) * kp * 1e9 
	Epp = (1-nu^2) / (2*a1) * (1-1/6*(a0/a1)^(3/2) ) / (1-(a0/a1)^(3/2) ) * kpp * 1e9 
	

end


//function RheCalcModDMT(kp,kpp,Ep,Epp,nu,force,force_adh,rad)
//	wave kp, kpp, Ep, Epp     						// storage stiffness, loss stiffness, storage modulus, loss modulus 
//	variable nu,force, force_adh, rad //, ind			// Poisson's ratio, Average Force (nN), Adhesive Force (nN), tip radius (nm), relative indentation between zero point and contact point (nm) 
//	
//		
////	variable a = (rad*ind)^(1/2)
//
//	print  ( 6^(1/2)*rad^(1/2)*(force+force_adh)^(1/2)
//
//	Ep = (1-nu^2)*kp^(3/2) / ( 6^(1/2)*rad^(1/2)*(force+force_adh)^(1/2) )				// Need to double check these equations (RW 1/9/19) 
//	Epp = (1-nu^2) *kpp*Ep^(1/3)  / ( 6^(1/3)*rad^(1/3)*(force+force_adh)^(1/3) )
//	
//	variable ind = ( 3*(force+force_adh)*(1-nu^2) / ( 4*Ep*rad^(1/2) ) )^(2/3)
//	variable a = (rad*ind)^(1/2)
//	
//	print "ind = ", ind
//	print "a = ", a
//
//end 

function RheJKRcontactArea(force,force_adh,ind,rad)	
	
	// Converts experimental observables (adhesive force, indentation, tip radius) into contact radius at an abritrary force.  
	//  This is the JKR "two point method" and we are assuming that these observables are not effected by viscoelasticity.  
	// From SI of Nakajima, Macromolecules, 2013 - Nanorheological Mapping of Rubbers by Atomic Force Microscopy
	// https://pubs.acs.org/doi/suppl/10.1021/ma302616a/suppl_file/ma302616a_si_001.pdf
			
	variable force,force_adh,rad,ind   // Force (nN), Adhesive Force (nN), contact radius (nm), relative indentation between zero point and contact point (nm) 
		  
	variable adh_e = 2*force_adh/(3*pi*rad)       																					//  adhesive energy (nN/nm)	
	variable t_mod = ( ( 1+16^(1/3) ) / 3 )^(3/2) * force_adh / ( rad^(1/2) * ind^(3/2) )   													// temporary modulus (GPa)	
	variable a = ( rad/t_mod * (force + 3*pi*adh_e*rad + sqrt( abs(6*pi*adh_e*rad*force + ( 3*pi*adh_e*rad )^2 ) ))  )^(1/3)						// contact area (nm)		
	
	if  (-force!=force_adh) 
		print "temp mod (MPa) = ", t_mod*1e3
		print "adhesive energy (N/m)", adh_e
	else 
	//	print "test1", 6*pi*adh_e*rad*force +  ( 3*pi*adh_e*rad )^2
	endif 
	
	return(a)
end

/// End data analysis stuff /// 


// Macrobuilder button 

//////   This needs to be put in x-calculated or user calculated and uncommented to work with macrobuilder.  ///////////////


//Function/S RheologyModule(ParmStr)
//                String ParmStr
//               
//                String output = ""
//               
//               
//                Struct ARMacroStruct ParmStruct
//                Struct ARMacroParmStruct Argument
//                if (StringMatch(ParmStr[0,strlen(cMacroShort)-1],"Info*"))
//                                ParmStruct.Name = "Rheology"
//                                ParmStruct.Pict = "Force1"
//                                ParmStruct.FuncName = GetFuncName()
//                                ParmStruct.CallbackName = "ForceDone"                            //Name of the UserCallback that will trigger the next step.
//                                ParmStruct.NumParms = 0
//                                ParmStruct.Type = "RealTime"
//                                ParmStruct.KeyWords = "Force,Frequency,Sweep,Rheology,CTFCRamp,"
//                                ParmStruct.Requires = "NanoRheology"
//                                ParmStruct.help = "This module will do a Rheology Experiment"
//                                if (StringMatch(ParmStr[0,strlen(cMacroShort)-1],cMacroShort))
//                                                ParmStruct.NumParms = 0
//                                                output = ARMacroStruct2String(ParmStruct)
//                                                return(Output)
//                                endif
//               
//                                output = ARMacroStruct2String(ParmStruct)
//                                return(Output)
//                endif
//                //we are passed all the parms we need.
//                //convert them to a structure for use.
//               
// 
//                ARMacroString2Struct(ParmStruct,ParmStr)
//               
//               
//                //This module, all the parms are standard
//               
//                //DoForceFunc("SingleForce_2")
//                Execute/Q/Z "RheologyMasterFunction()"
//               
//                //here we call the realtime function that does the real work.
//               
//                //if your function is synchronous [compleats all work in this function, and does not need a callback]
//                //then you should enable the following line:
//                //execute/P/Q/Z "ARCallbackFunc(\""+ParmStruct.CallbackName+"\")"
//               
//               
//                return(output)
//End //RheologyModule




//////////////////////////////////////////////////////////////////////////////////////////



///// Test functions  ////////

function RheIncVal()

	cd root:rheology

	make /free AmpVals = {.5, 1, 2, 4}
	nvar count 
	
	wave rvw 
	print count, AmpVals[count]
	rvw[%rheDriveAmp] = AmpVals[count]

	
	count += 1

end


function RheAmpCompFunc()
	
	string DataFolder = "root:rheology:test"    
	If (!DataFolderExists(DataFolder))
		newdatafolder $DataFolder
	endif	
	setdatafolder $DataFolder


	variable i, npts 
	npts = 8 
	
	string pathstr, namestr, liststr, rvw   
	
	
	make /free r_vals = {65280,65280,0,0,0,43520,15872,65280,65280,65280,0,0,0,43520,15872,65280}
	make /free g_vals = {0,43520,15872,65280,0,0,65280,0,0,43520,15872,65280,0,0,65280,0}
	make /free b_vals = {0,0,65280,0,65280,65280,0,0,0,0,65280,0,65280,65280,0,0}
	
	DoWindow /f RheTestComp
	if (V_flag == 1)
		GetWindow RheTestComp wsizeRM
		DoWindow /k RheTestComp   
		Display /N=RheTestComp /W=(V_left,V_top,V_right,V_bottom) as "Data Comparison" // note '/N=' flag
	else
		DoWindow /k RheTestComp   
		Display /N=RheTestComp /W=(50,50,550,550) as "Data Comparison" // note '/N=' flag
	endif


//	string basename = "sampD_"
	string basename = "sampE_"

	for (i=0; i<npts; i+=1)

		pathstr = "root:rheology:" + basename + "000" + num2str(i) + ":magTFc"
		liststr = "root:rheology:" + basename + "000" + num2str(i) + ":rvw"
		namestr = basename + "000" + num2str(i)
		rvw = basename + "000" + num2str(i) + "_rvw"

		print pathstr 
		wave tempwave = $pathstr 
		wave templist = $liststr 
		duplicate /o tempwave, $namestr 
		duplicate /o templist, $rvw 
		wave namewave = $namestr
		wave namervw = $rvw
//		setscale d, 0, 1, "m/v", namewave
		setscale d, 0, 1, "m", namewave
				 
		string temp_note = note($rvw) 
		variable temp_kL = numberbykey("SpringConstant", temp_note, ":","\r",0)
		variable temp_cL = numberbykey("InvOLS", temp_note, ":","\r",0)
		
//		namewave = namewave*temp_cL/namervw[%rheDriveAmp]
		namewave = namewave*temp_cL
		
		
		if(i==0)
			display /host = RheTestComp  /W=(.01,.01,.99,.99) $namestr
			modifygraph rgb = (r_vals[i],g_vals[i],b_vals[i])
		else
			appendtograph $namestr	
			modifygraph rgb[i-1] = (r_vals[i],g_vals[i],b_vals[i])	
		endif 
		
		//wave AC160_rvw = root:rheology:AC160_ref0000:rvw
		//duplicate /o AC160_ref, AC160_cal	
		//string AC160_note = note(AC160_rvw) 
		//variable AC160_kL = numberbykey("SpringConstant", AC160_note, ":","\r",0)
		//variable AC160_cL = numberbykey("InvOLS", AC160_note, ":","\r",0)
		//AC160_cal = AC160_cal*AC160_cL
		//setscale d, 0, 1, "m", AC160_cal		


	endfor
	

	Label left "Amplitude"
	Label bottom "Frequency"
	modifygraph log(bottom) = 1
	modifygraph fsize = 16
	modifygraph lsize = 3
	
	return(0)


//	
//	
//	wave AC240_ref = root:rheology:AC240_ref0000:magTFc
//	wave AC240_rvw = root:rheology:AC240_ref0000:rvw
//	duplicate /o AC240_ref, AC240_cal	
//	string AC240_note = note(AC240_rvw) 
//	variable AC240_kL = numberbykey("SpringConstant", AC240_note, ":","\r",0)
//	variable AC240_cL = numberbykey("InvOLS", AC240_note, ":","\r",0)
//	AC240_cal = AC240_cal*AC240_cL
//	setscale d, 0, 1, "m", AC240_cal
//	
//	
//	
//	
//	wave BioAC_ref = root:rheology:qp_BioAC_SPL_ref0000:magTFc
//	wave BioAC_rvw = root:rheology:qp_BioAC_SPL_ref0000:rvw
//	duplicate /o BioAC_ref, BioAC_cal	
//	string BioAC_note = note(BioAC_rvw) 
//	variable BioAC_kL = numberbykey("SpringConstant", BioAC_note, ":","\r",0)
//	variable BioAC_cL = numberbykey("InvOLS", BioAC_note, ":","\r",0)
//	BioAC_cal = BioAC_cal*BioAC_cL
//	setscale d, 0, 1, "m", BioAC_cal	
//	
//	
//	wave BioLever_ref = root:rheology:BioLev_ref0000:magTFc
//	wave BioLever_rvw = root:rheology:BioLev_ref0000:rvw
//	duplicate /o BioLever_ref, BioLever_cal	
//	string BioLever_note = note(BioLever_rvw) 
//	variable BioLever_kL = numberbykey("SpringConstant", BioLever_note, ":","\r",0)
//	variable BioLever_cL = numberbykey("InvOLS", BioLever_note, ":","\r",0)
//	BioLever_cal = BioLever_cal*BioLever_cL
//	setscale d, 0, 1, "m", BioLever_cal
//	
//	
//	DoWindow /f RheLeverComp
//	if (V_flag == 1)
//		GetWindow RheLeverComp wsizeRM
//		DoWindow /k RheLeverComp   
//		Display /N=RheLeverComp /W=(V_left,V_top,V_right,V_bottom) as "Lever Comparison" // note '/N=' flag
//	else
//		DoWindow /k RheLeverComp   
//		Display /N=RheLeverComp /W=(50,50,550,550) as "Lever Comparison" // note '/N=' flag
//	endif
//	
//
//	Display /host = RheLeverComp  /W=(.01,.01,.99,.99)  BioAC_cal
//	appendtograph AC240_cal 
//	appendtograph AC160_cal  
//	appendtograph BioLever_cal
////	modifygraph log = 1
//	modifygraph log(bottom) = 1
//	modifygraph fsize = 16
//	modifygraph lsize = 3
////	Label left "Amplitude (\\U)"
////	Label bottom "Frequency (\\U)"
//	
//	Label left "Amplitude"
//	Label bottom "Frequency"
//
//
//	
//	Legend /C/N=text0/J/H={0,2,10} /A=LB "\Z16\\s(#0) BioAC \r\\s(#1) AC240 \r\\s(#2) AC160 \r\\s(#3) BioLever"
//	
//	ModifyGraph rgb[0]=(65280,0,0)
//	ModifyGraph rgb[1]=(65280,43520,0)
//	ModifyGraph rgb[2]=(0,15872,65280)
//	ModifyGraph rgb[3]=(0,65280,0)	
//	
//


end



function RheCompFunc()
	
	string DataFolder = "root:rheology:test"    
	If (!DataFolderExists(DataFolder))
		newdatafolder $DataFolder
	endif	
	setdatafolder $DataFolder


	variable i, npts 
	npts = 2 
	
	string pathstr, namestr, liststr, rvw   
	
	
	make /free r_vals = {65280,65280,0,0,0,43520,15872,65280,65280,65280,0,0,0,43520,15872,65280}
	make /free g_vals = {0,43520,15872,65280,0,0,65280,0,0,43520,15872,65280,0,0,65280,0}
	make /free b_vals = {0,0,65280,0,65280,65280,0,0,0,0,65280,0,65280,65280,0,0}
	
	DoWindow /f RheTestComp
	if (V_flag == 1)
		GetWindow RheTestComp wsizeRM
		DoWindow /k RheTestComp   
		Display /N=RheTestComp /W=(V_left,V_top,V_right,V_bottom) as "Data Comparison" // note '/N=' flag
	else
		DoWindow /k RheTestComp   
		Display /N=RheTestComp /W=(50,50,550,550) as "Data Comparison" // note '/N=' flag
	endif


	string basename1 = "sampE_0002"
	string basename2 = "sampD_0002"
	make /t /free /n = 2 basenames 
	basenames = {basename1, basename2}

	for (i=0; i<npts; i+=1)

		pathstr = "root:rheology:" + basenames[i] + ":magTFc"
		liststr = "root:rheology:" + basenames[i] + ":rvw"
		namestr = basenames[i]
		rvw = basenames[i] + "_rvw"

		print pathstr 
		wave tempwave = $pathstr 
		wave templist = $liststr 
		duplicate /o tempwave, $namestr 
		duplicate /o templist, $rvw 
		wave namewave = $namestr
		wave namervw = $rvw
//		setscale d, 0, 1, "m/v", namewave
		setscale d, 0, 1, "m", namewave
				 
		string temp_note = note($rvw) 
		variable temp_kL = numberbykey("SpringConstant", temp_note, ":","\r",0)
		variable temp_cL = numberbykey("InvOLS", temp_note, ":","\r",0)
		
//		namewave = namewave*temp_cL/namervw[%rheDriveAmp]
		namewave = namewave*temp_cL
		
		
		if(i==0)
			display /host = RheTestComp  /W=(.01,.01,.99,.99) $namestr
			modifygraph rgb = (r_vals[i],g_vals[i],b_vals[i])
		else
			appendtograph $namestr	
			modifygraph rgb[i-1] = (r_vals[i],g_vals[i],b_vals[i])	
		endif 
		
		//wave AC160_rvw = root:rheology:AC160_ref0000:rvw
		//duplicate /o AC160_ref, AC160_cal	
		//string AC160_note = note(AC160_rvw) 
		//variable AC160_kL = numberbykey("SpringConstant", AC160_note, ":","\r",0)
		//variable AC160_cL = numberbykey("InvOLS", AC160_note, ":","\r",0)
		//AC160_cal = AC160_cal*AC160_cL
		//setscale d, 0, 1, "m", AC160_cal		


	endfor
	

	Label left "Amplitude"
	Label bottom "Frequency"
	modifygraph log(bottom) = 1
	modifygraph fsize = 16
	modifygraph lsize = 3



end


function RheplotFTcurve([filename])	
	string FileName 
	If (ParamIsDefault(FileName))
                FileName = ""
	Endif
		
	String DataFolder = "root:rheology"
	If (Strlen(FileName))
	                DataFolder += ":"+FileName
	Endif

	If (!DataFolderExists(DataFolder))
      		Print "Bad Filename, does not exists "+FileName
		Return 0
	Endif
	SetDataFolder(DataFolder)
	
//	wave App = root:rheology:samp0022:AppDefl
//	wave Dwell = root:rheology:samp0022:DriveDefl
//	wave With = root:rheology:samp0022:WithDefl
//	wave rvw = root:rheology:samp0022:rvw

	wave App =AppDefl
	wave Dwell =DriveDefl
	wave With = WithDefl
	wave rvw = rvw


	newdatafolder /o /s FvT
	
	duplicate /o App, AppP
	duplicate /o Dwell, DwellP
	duplicate /o With, WithP
	
	variable Apptime = dimsize(AppP,0)*dimdelta(AppP,0)
	variable Dwelltime = dimsize(DwellP,0)*dimdelta(DwellP,0)
	variable Withtime = dimsize(WithP,0)*dimdelta(WithP,0)

	variable delta = .5
	
	setscale x, 0, Apptime, AppP
	setscale x, Apptime+delta, dwelltime+Apptime+delta, DwellP
	setscale x, Apptime+dwelltime+2*delta, withtime+dwelltime+Apptime+2*delta, WithP
	
	setscale d, -1, 1, "m", AppP
	setscale d, -1, 1, "m", DwellP
	setscale d, -1, 1, "m", WithP
	
	string notestring = note(rvw)
	variable ols = numberbykey("InvOLS", notestring, ":","\r",0)
	
	AppP = (AppP-App[0])*ols
	DwellP = (DwellP-App[0])*ols
	WithP = (WithP-App[0])*ols
	
	DoWindow /f FTcurve
	if (V_flag == 1)
		GetWindow FTcurve wsizeRM
		DoWindow /k FTcurve   
		Display /N=FTcurve /W=(V_left,V_top,V_right,V_bottom) as "Force vs. Time" // note '/N=' flag
	else
		DoWindow /k FTcurve   
		Display /N=FTcurve /W=(50,50,350,250) as "Force vs. Time" // note '/N=' flag
	endif 
	
	
	display /host = FTcurve /W=(.01,.01,.99,.99)  /n = f AppP
//	display /host = RheologySmooth /W=(.01,.01,.99,.50)  /N=tands tandT100s
	appendtograph  /w = FTcurve#f DwellP
	appendtograph /w = FTcurve#f WithP
	ModifyGraph rgb(AppP)=(16384,65280,16384)
	ModifyGraph rgb(WithP)=(0,0,65280)
	ModifyGraph lsize=3
	Label left "Cantilever Deflection (\\U)"
	Label bottom "Time (\\U)"
	ModifyGraph fSize=16

	Legend/C/N=text0/J/F=0/H={0,2,10}/A=LB "\\s(AppP) \\Z16 Approach\r\\s(DwellP) Dwell\r\\s(WithP) Withdraw"


end