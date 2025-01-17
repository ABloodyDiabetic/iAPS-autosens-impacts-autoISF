import SwiftUI

extension AutoISFConf {
    final class StateModel: BaseStateModel<Provider>, PreferencesSettable {
        private(set) var preferences = Preferences()
        @Injected() var settings: SettingsManager!
        @Injected() var storage: FileStorage!

        @Published var unit: GlucoseUnits = .mmolL
        @Published var sections: [FieldSection] = []
        @Published var autoisf: Bool = false

        func updateAutosensSettings(enableAutosens: Bool) {
            guard let preferences = storage.retrieve(OpenAPS.Settings.preferences, as: Preferences.self) else {
                debug(.openAPS, "Error loading preferences in updateAutosensSettings")
                return
            }

            var updatedPreferences = preferences
            if enableAutosens {
                updatedPreferences.enableAutosens = true
            }
            updatedPreferences.useAutosensIsfToCalculateAutoIsfSens = enableAutosens

            storage.save(updatedPreferences, as: OpenAPS.Settings.preferences)
        }

        func updateCarbProfileSettings(enableLowCarb: Bool? = nil, enableModerateCarb: Bool? = nil, enableHighCarb: Bool? = nil) {
            guard var preferences = storage.retrieve(OpenAPS.Settings.preferences, as: Preferences.self) else {
                debug(.openAPS, "Error loading preferences in updateCarbProfileSettings")
                return
            }

            if let enableLowCarb = enableLowCarb {
                preferences.lowCarbezFCLProfile = enableLowCarb
                preferences.moderateCarbezFCLProfile = false
                preferences.highCarbezFCLProfile = false
            }

            if let enableModerateCarb = enableModerateCarb {
                preferences.moderateCarbezFCLProfile = enableModerateCarb
                preferences.lowCarbezFCLProfile = false
                preferences.highCarbezFCLProfile = false
//                scheduleReset()
            }

            if let enableHighCarb = enableHighCarb {
                preferences.highCarbezFCLProfile = enableHighCarb
                preferences.lowCarbezFCLProfile = false
                preferences.moderateCarbezFCLProfile = false
//                scheduleReset()
            }

            storage.save(preferences, as: OpenAPS.Settings.preferences)
        }

//        func scheduleReset() {
//            DispatchQueue.main.asyncAfter(deadline: .now() + (0.05 * 3600)) { [weak self] in
//                guard let self = self else { return }
//                self.updateCarbProfileSettings(enableLowCarb: true)
//            }
//        }

        override func subscribe() {
            unit = settingsManager.settings.units
            preferences = provider.preferences
            autoisf = settings.preferences.autoisf

            // MARK: - autoISF fields

            let profileControls = [
                Field(
                    displayName: "Low Carb Profile (Default)",
                    type: .boolean(keypath: \Preferences.lowCarbezFCLProfile),
                    infoText: NSLocalizedString(
                        "Defaults to true. When true, sets your FCL profile to the least aggressive profile that can effectively handle dosing for low carb meals automatically with minimal risk of overdelivery of insulin.",
                        comment: "Low Carb FCL Profile"
                    ),
                    settable: self,
                    onChange: { [weak self] newValue in
                        if let newValue = newValue as? Bool {
                            print("Low Carb Profile changed to: \(newValue)")
                            self?.updateCarbProfileSettings(enableLowCarb: newValue)
                            if newValue {
                                self?.preferences.highCarbezFCLProfile = false
                                self?.preferences.moderateCarbezFCLProfile = false
                            }
                        }
                    }
                ),
                Field(
                    displayName: "Medium Carb Profile",
                    type: .boolean(keypath: \Preferences.moderateCarbezFCLProfile),
                    infoText: NSLocalizedString(
                        "When enabled, sets your FCL profile to a moderate profile. Use this profile for meals that are carby, but not excessively so.",
                        comment: "Moderate Carb FCL Profile"
                    ),
                    settable: self,
                    onChange: { [weak self] newValue in
                        if let newValue = newValue as? Bool {
                            print("Moderate Carb Profile changed to: \(newValue)")
                            self?.updateCarbProfileSettings(enableModerateCarb: newValue)
                            if newValue {
                                self?.preferences.lowCarbezFCLProfile = false
                                self?.preferences.highCarbezFCLProfile = false
                            }
                        }
                    }
                ),
                Field(
                    displayName: "High Carb Profile",
                    type: .boolean(keypath: \Preferences.highCarbezFCLProfile),
                    infoText: NSLocalizedString(
                        "When enabled, sets your FCL profile to the most aggressive profile, suitable for handling high carb meals.",
                        comment: "High Carb FCL Profile"
                    ),
                    settable: self,
                    onChange: { [weak self] newValue in
                        if let newValue = newValue as? Bool {
                            print("High Carb Profile changed to: \(newValue)")
                            self?.updateCarbProfileSettings(enableHighCarb: newValue)
                            if newValue {
                                self?.preferences.lowCarbezFCLProfile = false
                                self?.preferences.moderateCarbezFCLProfile = false
                            }
                        }
                    }
                )
//                Field(
//                    displayName: "Profile Duration",
//                    type: .decimal(keypath: \.profileDuration),
//                    infoText: NSLocalizedString(
//                        "Defaults to 6 hours. This is the duration that a Moderate or High Carb Profile will remain active for before the profile is deactivated and the Low Carb Profile is reenacted.",
//                        comment: "Profile Duration"
//                    ),
//                    settable: self
//                )
            ]
            let autoisfConfig = [
                //                Field(
//                    displayName: NSLocalizedString("Enable Autosens", comment: "Enable Autosens"),
//                    type: .boolean(keypath: \.enableAutosens),
//                    infoText: NSLocalizedString(
//                        "Switch Autosens on/off",
//                        comment: "Autosens"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "Exercise Mode",
//                    type: .boolean(keypath: \.exerciseMode),
//                    infoText: NSLocalizedString(
//                        "Defaults to false. When true, > 100 mg/dL high temp target adjusts sensitivityRatio for exercise mode. Synonym for high_temptarget_raises_sensitivity",
//                        comment: "Exercise Mode"
//                    ),
//                    settable: self
//                ),
                Field(
                    displayName: "Switch off FCL when 'Excercise Mode' is enabled",
                    type: .boolean(keypath: \.autoISFoffSport),
                    infoText: NSLocalizedString(
                        "Defaults to true. When true, switches off ezFCL completely during high TT in excercise mode.",
                        comment: "Switch off ezFCL with exercise"
                    ),
                    settable: self
                ),
//                Field(
//                    displayName: NSLocalizedString("Half Basal Exercise Target", comment: "Half Basal Exercise Target") +
//                        " (mg/dL)",
//                    type: .decimal(keypath: \.halfBasalExerciseTarget),
//                    infoText: NSLocalizedString(
//                        "Set to a number in mg/dl, e.g. 160, which means when TempTarget (TT) is 160 mg/dL and exercise mode = true, it will run 50% basal at this TT level (if high TT at 120 = 75%; 140 = 60%). This can be adjusted, to give you more control over your exercise modes.",
//                        comment: "Half Basal Exercise Target"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "Odd Temp Targets (TTs) disable MBs for ezFCL",
//                    type: .boolean(keypath: \.enableSMBEvenOnOddOff),
//                    infoText: NSLocalizedString(
//                        "Defaults to false. If true, ezFCL will block MB's when odd TempTargets are used (lower boundary) and enforce MB, when even TempTargets are used. ezFCL is still active and adjusting ISF's. In case of exercise_mode or high_temptarget_raises_sensitivity being true and any High TT being active, it adjusts the oref calculataed ISF, not profile ISF. Only appliccable if ezFCL is enabled.",
//                        comment: "Odd TT disable MB"
//                    ),
//                    settable: self
//                ),
                Field(
                    displayName: "Odd Profile Targets disable MBs for FCL",
                    type: .boolean(keypath: \.enableSMBEvenOnOddOffalways),
                    infoText: NSLocalizedString(
                        "Defaults to false. If true, ezFCL will block MB's when odd ProfileTargets are used (lower boundary = upper boundary)",
                        comment: "Odd Target disable SMB"
                    ),
                    settable: self
                )
            ]

//            let xpmToogles = [
//                Field(
//                    displayName: NSLocalizedString("Max IOB %", comment: "Max IOB %"),
//                    type: .decimal(keypath: \.maxIOB),
//                    infoText: NSLocalizedString(
//                        "Max IOB is the maximum amount of insulin on board from all sources – both basal (or SMB correction) and bolus insulin – that your loop is allowed to accumulate to treat higher-than-target BG. max_iob is set as a percentage of the TDD to allow dynamic adjustment. As of now, manual boluses are NOT limited by this setting. \n\n To test your basal rates during nighttime, you can modify the Max IOB setting to zero while in Closed Loop. This will enable low glucose suspend mode while testing your basal rates settings.",
//                        comment: "Max IOB %"
//                    ),
//                    settable: self
//                )
//                Field(
//                    displayName: "autoISF IOB Threshold Percent",
//                    type: .decimal(keypath: \.iobThresholdPercent),
//                    infoText: NSLocalizedString(
//                        "Default value: 100%. This is the share of maxIOB above which autoISF will disable SMB. Relative level of maxIOB above which SMBs are disabled. With 100% this feature is effectively disabled.",
//                        comment: "autoISF IOB threshold percent"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "autoISF Max",
//                    type: .decimal(keypath: \.autoISFmax),
//                    infoText: NSLocalizedString(
//                        "Multiplier cap on how high the autoISF ratio can be and therefore how low it can adjust ISF.",
//                        comment: "autoISF Max"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "autoISF Min",
//                    type: .decimal(keypath: \.autoISFmin),
//                    infoText: NSLocalizedString(
//                        "This is a multiplier cap for autoISF to set a limit on how low the autoISF ratio can be, which in turn determines how high it can adjust ISF.",
//                        comment: "autoISF Min"
//                    ),
//                    settable: self
//                ),
//            ]
            let xpmProfileMultipliers = [
                Field(
                    displayName: "Low Carb Profile Multiplier",
                    type: .decimal(keypath: \.lowCarbezFCLProfileMultiplier),
                    infoText: NSLocalizedString(
                        "This is multiplied by the 'FCL Weight' to determine how aggressive the 'Low Carb FCL Profile' is when calculating insulin doses according to the acceleration, delta, and plateau durations.",
                        comment: "Low Carb Profile Multiplier"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Moderate Carb Profile Multiplier",
                    type: .decimal(keypath: \.moderateCarbezFCLProfileMultiplier),
                    infoText: NSLocalizedString(
                        "This is multiplied by the 'FCL Weight' to determine how aggressive the 'Moderate Carb FCL Profile' is when calculating insulin doses according to the acceleration, delta, and plateau durations.",
                        comment: "Moderate Carb Profile Multiplier"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "High Carb Profile Multiplier",
                    type: .decimal(keypath: \.highCarbezFCLProfileMultiplier),
                    infoText: NSLocalizedString(
                        "This is multiplied by the 'FCL Weight' to determine how aggressive the 'High Carb FCL Profile' is when calculating insulin doses according to the acceleration, delta, and plateau durations.",
                        comment: "High Carb Profile Multiplier"
                    ),
                    settable: self
                )
            ]
            let xpmFCLWeight = [
                Field(
                    displayName: "FCL Weight",
                    type: .decimal(keypath: \.ezFCLWeight),
                    infoText: NSLocalizedString(
                        "This weight determines how aggressive ezFCL is when calculating insulin doses according to the acceleration, delta, and plateau durations.",
                        comment: "ezFCL Weight"
                    ),
                    settable: self
                )
            ]
            let xpmFCLSubcategoryWeights = [
                Field(
                    displayName: "Acceleration Multiplier",
                    type: .decimal(keypath: \.ezFCLAccelerationMultiplier),
                    infoText: NSLocalizedString(
                        "This multiplier determines how aggressive ezFCL is when calculating insulin doses according to the acceleration and deceleration of glucose values.",
                        comment: "Acceleration Multiplier"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Delta Multiplier",
                    type: .decimal(keypath: \.ezFCLDeltaMultiplier),
                    infoText: NSLocalizedString(
                        "This multiplier determines how aggressive ezFCL is when calculating insulin doses according to the deltas between glucose values readings every five minutes.",
                        comment: "Delta Multiplier"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Plateau Multiplier",
                    type: .decimal(keypath: \.ezFCLPlateauMultiplier),
                    infoText: NSLocalizedString(
                        "This multiplier determines how aggressively ezFCL reacts towards stubborn highs or glucose plateaus when glucose values have been stuck at elevated levels for a prolonged period of time. The plateau weight gradually increases up to its maximum and or until glucose levels start coming back down, at which point, it quickly reverts to a neutral value of 1 to avoid over-delivery of insulin. This is a very controlled method of handling stuck BGs/classic transient insulin resistance.",
                        comment: "Plateau Multiplier"
                    ),
                    settable: self
                )
            ]
            let xpmDuraISF = [
                //                Field(
//                    displayName: "Enable DuraISF effect with COB",
//                    type: .boolean(keypath: \.enableautoISFwithCOB),
//                    infoText: NSLocalizedString(
//                        "Enable DuraISF even if COB is present not just for UAM.",
//                        comment: "Enable autoISF with COB"
//                    ),
//                    settable: self
//                ),
                Field(
                    displayName: "DuraISF weight",
                    type: .decimal(keypath: \.autoISFhourlyChange),
                    infoText: NSLocalizedString(
                        "Rate at which ISF is reduced per hour assuming BG leveel remains at double target for that time. When value = 1.0, ISF is reduced to 50% after 1 hour of BG level at 2x target.",
                        comment: "autoISF HourlyMaxChange"
                    ),
                    settable: self
                )
            ]

//            let xpmBGISF = [
//                Field(
//                    displayName: "ISF weight for lower BG's",
//                    type: .decimal(keypath: \.lowerISFrangeWeight),
//                    infoText: NSLocalizedString(
//                        "Default value: 0.0 This is the weight applied to the polygon which adapts ISF if glucose is below target. With 0.0 the effect is effectively disabled.",
//                        comment: "ISF low BG weight"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "ISF weight for higher BG's",
//                    type: .decimal(keypath: \.higherISFrangeWeight),
//                    infoText: NSLocalizedString(
//                        "Default value: 0.0 This is the weight applied to the polygon which adapts ISF if glucose is above target. With 0.0 the effect is effectively disabled.",
//                        comment: "ISF high BG weight"
//                    ),
//                    settable: self
//                )
//            ]
//            let xpmDeltaISF = [
//                Field(
//                    displayName: "ISF weight for higher BG deltas",
//                    type: .decimal(keypath: \.deltaISFrangeWeight),
//                    infoText: NSLocalizedString(
//                        "Default value: 0.0 This is the weight applied to the polygon which adapts ISF higher deltas. With 0.0 the effect is effectively disabled.",
//                        comment: "ISF higher delta BG weight"
//                    ),
//                    settable: self
//                )
//            ]

            let xpmAcceISF = [
                //                Field(
//                    displayName: "Enable BG acceleration",
//                    type: .boolean(keypath: \.enableBGacceleration),
//                    infoText: NSLocalizedString(
//                        "Enables the BG acceleration adaptions, adjusting ISF for accelerating/decelerating blood glucose.",
//                        comment: "Enable BG accel in autoISF"
//                    ),
//                    settable: self
//                ),
                Field(
                    displayName: "ISF weight while BG accelerates",
                    type: .decimal(keypath: \.bgAccelISFweight),
                    infoText: NSLocalizedString(
                        "Default value: 0. This is the weight applied while glucose accelerates and which strengthens ISF. With 0 this contribution is effectively disabled. 0.02 is a safe starting point, from which to move up. Typical settings are around 0.15!",
                        comment: "ISF acceleration weight"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "ISF weight while BG decelerates",
                    type: .decimal(keypath: \.bgBrakeISFweight),
                    infoText: NSLocalizedString(
                        "Default value: 0. This is the weight applied while glucose decelerates and which weakens ISF. With 0 this contribution is effectively disabled. 0.1 might be a good starting point.",
                        comment: "ISF decceleration weight"
                    ),
                    settable: self
                )
            ]

            let xpmPostPrandial = [
                //                Field(
//                    displayName: "Enable always postprandial ISF adaption",
//                    type: .boolean(keypath: \.postMealISFalways),
//                    infoText: NSLocalizedString(
//                        "Enable the postprandial ISF adaptation all the time regardless of when the last meal was taken.",
//                        comment: "Enable postprandial ISF always"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "Duration ISF postprandial adaption",
//                    type: .decimal(keypath: \.postMealISFduration),
//                    infoText: NSLocalizedString(
//                        "Default value: 3 This is the duration in hours how long after a meal the effect will be active. Oref will delete carb timing after 10 hours latest no matter what you enter.",
//                        comment: "ISF postprandial change duration"
//                    ),
//                    settable: self
//                ),
                Field(
                    displayName: "ISF weight for postprandial BG rise",
                    type: .decimal(keypath: \.postMealISFweight),
                    infoText: NSLocalizedString(
                        "Default value: 0 This is the weight applied to the linear slope while glucose rises and  which adapts ISF. With 0 this contribution is effectively disabled. Start with 0.01 - it hardly goes beyond 0.05!",
                        comment: "ISF postprandial weight"
                    ),
                    settable: self
                )
            ]

//            let xpmSMB = [
//                Field(
//                    displayName: "SMB DeliveryRatio",
//                    type: .decimal(keypath: \.smbDeliveryRatio),
//                    infoText: NSLocalizedString(
//                        "Default value: 0.5 This is another key OpenAPS safety cap, and specifies what share of the total insulin required can be delivered as SMB. This is to prevent people from getting into dangerous territory by setting SMB requests from the caregivers phone at the same time. Increase this experimental value slowly and with caution. YOu can use that with autoISF to increase the SMB DR immediatly indpendant of BG if you use an Eating Soon TT (even and below 100). This SMB DR will than be used, independantly of the 3 following options, that normally superceed his setting.",
//                        comment: "SMB DeliveryRatio"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "SMB DeliveryRatio BG Minimum",
//                    type: .decimal(keypath: \.smbDeliveryRatioMin),
//                    infoText: NSLocalizedString(
//                        "Default value: 0.5 This is the lower end of a linearly increasing SMB Delivery Ratio rather than the fix value above in SMB DeliveryRatio.",
//                        comment: "SMB DeliveryRatio Minimum"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "SMB DeliveryRatio BG Maximum",
//                    type: .decimal(keypath: \.smbDeliveryRatioMax),
//                    infoText: NSLocalizedString(
//                        "Default value: 0.5 This is the higher end of a linearly increasing SMB Delivery Ratio rather than the fix value above in SMB DeliveryRatio.",
//                        comment: "SMB DeliveryRatio Minimum"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "SMB DeliveryRatio BG Range",
//                    type: .decimal(keypath: \.smbDeliveryRatioBGrange),
//                    infoText: NSLocalizedString(
//                        "Default value: 0, Sensible is bteween 40 and 120. The linearly increasing SMB delivery ratio is mapped to the glucose range [target_bg, target_bg+bg_range]. At target_bg the SMB ratio is smb_delivery_ratio_min, at target_bg+bg_range it is smb_delivery_ratio_max. With 0 the linearly increasing SMB ratio is disabled and the fix smb_delivery_ratio is used.",
//                        comment: "SMB DeliveryRatio BG Range"
//                    ),
//                    settable: self
//                ),
//                Field(
//                    displayName: "SMB Max RangeExtension",
//                    type: .decimal(keypath: \.smbMaxRangeExtension),
//                    infoText: NSLocalizedString(
//                        "Default value: 1. This is another key OpenAPS safety cap, and specifies by what factor you can exceed the regular 120 maxSMB/maxUAM minutes. Increase this experimental value slowly and with caution. Available only when autoISF is enabled.",
//                        comment: "SMB Max RangeExtension"
//                    ),
//                    settable: self
//                )
//            ]

            let xpmB30 = [
                Field(
                    displayName: "Enable B30 EatingSoon",
                    type: .boolean(keypath: \.enableB30),
                    infoText: NSLocalizedString(
                        "Enables an increased basal rate after an EatingSoon TT and a manual bolus to saturate the infusion site with insulin to increase insulin absorption for SMB's following a meal with no carb counting.",
                        comment: "Enable B30 for autoISF"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "TempTarget Level in mg/dl for B30 to be enacted",
                    type: .decimal(keypath: \.B30iTimeTarget),
                    infoText: NSLocalizedString(
                        "An EatingSoon TempTarget needs to be enabled to start B30 adaption. Set level for this target to be identified. Default is 90 mg/dl. If you cancel this EatingSoon TT also the B30 basal rate will stop.",
                        comment: "EatingSoon TT level"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Minimum Start Bolus size",
                    type: .decimal(keypath: \.B30iTimeStartBolus),
                    infoText: NSLocalizedString(
                        "Minimum manual bolus to start a B30 adaption.",
                        comment: "B30 Start Bolus size"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Duration of increased B30 basal rate",
                    type: .decimal(keypath: \.B30iTime),
                    infoText: NSLocalizedString(
                        "Duration of increased basal rate that saturates the infusion site with insulin. Default 30 minutes, as in B30. The EatingSoon TT needs to be running at least for this duration, otherthise B30 will stopp after the TT runs out.",
                        comment: "Duration of B30"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "B30 Basal rate increase factor",
                    type: .decimal(keypath: \.B30basalFactor),
                    infoText: NSLocalizedString(
                        "Factor that multiplies your regular basal rate from profile for B30. Default is 10.",
                        comment: "Basal rate factor B30"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Upper BG limit in mg/dl for B30",
                    type: .decimal(keypath: \.B30upperLimit),
                    infoText: NSLocalizedString(
                        "B30 will only run as long as BG stays underneath that level, if above regular ezFCL takes over. Default is 130 mg/dl.",
                        comment: "Upper BG for B30"
                    ),
                    settable: self
                ),
                Field(
                    displayName: "Upper Delta limit in mg/dl for B30",
                    type: .decimal(keypath: \.B30upperDelta),
                    infoText: NSLocalizedString(
                        "B30 will only run as long as BG delta stays below that level, if above regular ezFCL takes over. Default is 8 mg/dl.",
                        comment: "Upper Delta for B30"
                    ),
                    settable: self
                )
            ]

            sections = [
/*                FieldSection(
                    displayName: NSLocalizedString("Target Control", comment: "AutoISF control via Targets"),
                    fields: autoisfConfig
                ),*/
//                FieldSection(
//                    displayName: NSLocalizedString(
//                        "Toggles & general Settings",
//                        comment: "Switch on/off experimental stuff"
//                    ),
//                    fields: xpmToogles
//                ),
                FieldSection(
                    displayName: NSLocalizedString(
                        "Profile Multipliers",
                        comment: "Profile Multipliers"
                    ),
                    fields: xpmProfileMultipliers
                ),
                FieldSection(
                    displayName: NSLocalizedString(
                        "Primary FCL Weight",
                        comment: "Primary FCL Weight"
                    ),
                    fields: xpmFCLWeight
                ),
                FieldSection(
                    displayName: NSLocalizedString(
                        "FCL Subcategory Multipliers",
                        comment: "FCL Subcategory Multipliers"
                    ),
                    fields: xpmFCLSubcategoryWeights
                ),
                FieldSection(
                    displayName: NSLocalizedString(
                        "Acce-ISF settings",
                        comment: "Experimental settings for acceleration based autoISF 2.2"
                    ),
                    fields: xpmAcceISF
                ),
                FieldSection(
                    displayName: NSLocalizedString(
                        "PP-ISF settings",
                        comment: "Experimental settings for postprandial based autoISF 2.2"
                    ),
                    fields: xpmPostPrandial
                ),
//                FieldSection(
//                    displayName: NSLocalizedString(
//                        "Delta-ISF settings",
//                        comment: "Experimental settings for BG delta based autoISF2.1"
//                    ),
//                    fields: xpmDeltaISF
//                ),
//                FieldSection(
//                    displayName: NSLocalizedString(
//                        "BG-ISF settings",
//                        comment: "Experimental settings for BG level based autoISF2.1"
//                    ),
//                    fields: xpmBGISF
//                ),
                FieldSection(
                    displayName: NSLocalizedString(
                        "Dura-ISF settings",
                        comment: "Experimental settings for high BG plateau based autoISF2.0"
                    ),
                    fields: xpmDuraISF
                ),
//                FieldSection(
//                    displayName: NSLocalizedString(
//                        "SMB Delivery Ratio settings",
//                        comment: "Experimental settings for SMB increases autoISF 2.0"
//                    ),
//                    fields: xpmSMB
//                ),
/*                FieldSection(
                    displayName: NSLocalizedString("B30 settings", comment: "AIMI B30  settings"),
                    fields: xpmB30
                ),*/
               /* FieldSection(
                    displayName: NSLocalizedString("Profile Control", comment: "AutoISF control via Targets"),
                    fields: profileControls
                ) */
            ]
        }

        var unChanged: Bool {
            preferences.autoisf == autoisf
        }

        func convertBack(_ glucose: Decimal) -> Decimal {
            if unit == .mmolL {
                return glucose.asMgdL
            }
            return glucose
        }

        func save() {
            provider.savePreferences(preferences)
        }

        func set<T>(_ keypath: WritableKeyPath<Preferences, T>, value: T) {
            preferences[keyPath: keypath] = value
            save()
        }

        func get<T>(_ keypath: WritableKeyPath<Preferences, T>) -> T {
            preferences[keyPath: keypath]
        }

        func saveIfChanged() {
            if !unChanged {
                var newSettings = storage.retrieve(OpenAPS.Settings.preferences, as: Preferences.self) ?? Preferences()
                newSettings.autoisf = autoisf
                newSettings.timestamp = Date()
                storage.save(newSettings, as: OpenAPS.Settings.preferences)
            }
        }
    }
}
