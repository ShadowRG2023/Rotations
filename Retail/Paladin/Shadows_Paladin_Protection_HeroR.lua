--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item

-- Interrupt
local settings = {
  Interrupt = true,
  Stun = true,
}
addonTable:SetConfig(settings)

-- DO NOT REMOVE 
addonTable.spells = {
  { spell = "SPELL Word of Glory", name = "Word of Glory" },
  { spell = "SPELL Shield of the Righteous", name = "Shield of the Righteous" },
  { spell = "SPELL Sentinel", name = "Sentinel" },
  { spell = "SPELL Moment of Glory", name = "Moment of Glory" },
  { spell = "SPELL Layon Hands", name = "Layon Hands" },
  { spell = "SPELL Judgment", name = "Judgment" },
  { spell = "SPELL Hammer of the Righteous", name = "Hammer of the Righteous" },
  { spell = "SPELL Hammer of Wrath", name = "Hammer of Wrath" },
  { spell = "SPELL Guardian of Ancient Kings", name = "Guardian of Ancient Kings" },
  { spell = "SPELL Eye of Tyr", name = "Eye of Tyr" },
  { spell = "SPELL Divine Toll", name = "Divine Toll" },
  { spell = "SPELL Devotion Aura", name = "Devotion Aura" },
  { spell = "SPELL Crusader Strike", name = "Crusader Strike" },
  { spell = "SPELL Consecration", name = "Consecration" },
  { spell = "SPELL Blessed Hammer", name = "Blessed Hammer" },
  { spell = "SPELL Bastion of Light", name = "Bastion of Light" },
  { spell = "SPELL Avenging Wrath", name = "Avenging Wrath" },
  { spell = "SPELL Avenger's Shield", name = "Avenger's Shield" },
  { spell = "SPELL Ardent Defender", name = "Ardent Defender" },
  -- INTERRUPTS
  { spell = "SPELL Rebuke", name = "Rebuke" },
  { spell = "SPELL Hammer of Justice", name = "Hammer of Justice" },
  -- RACIALS
  { spell = "SPELL Blood Fury", name = "Blood Fury" },
  { spell = "SPELL Berserking", name = "Berserking" },
  { spell = "SPELL Bag of Tricks", name = "Bag of Tricks" },
  { spell = "SPELL Arcane Torrent", name = "Arcane Torrent" },
  { spell = "SPELL Arcane Pulse", name = "Arcane Pulse" },
  { spell = "SPELL Ancestral Call", name = "Ancestral Call" },
  { spell = "SPELL Light's Judgment", name = "Light's Judgment" },
  { spell = "SPELL Fireblood", name = "Fireblood" },
}

-- DO NOT REMOVE ^
addonTable.mapKeybinds(addonTable.spells)

-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Paladin.Protection
local I = Item.Paladin.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Interrupts List
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

-- Rotation Var
local ActiveMitigationNeeded
local IsTanking
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y
local VarSanctificationMaxStack = 5

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  CommonsDS = HR.GUISettings.APL.Paladin.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Paladin.CommonsOGCD,
  Protection = HR.GUISettings.APL.Paladin.Protection
}

-- Helper Functions
local function Interrupt()
  if Target:IsInterruptible() then
    if S.Rebuke:IsCastable() and Target:IsSpellInRange(S.Rebuke) and addonTable.config.Interrupt then
      if Cast(S.Rebuke) then
	      addonTable.cast("Rebuke")
	      return "rebuke 1"
	    end
    end
  end
  if S.HammerofJustice:IsCastable() and Target:IsSpellInRange(S.HammerofJustice) and addonTable.config.Stun and S.Rebuke:CooldownRemains() > 0.5 then
    if Cast(S.HammerofJustice) then
      addonTable.cast("Hammer of Justice")
      return "hammer_of_justice 1"
    end
  end
  if S.AvengersShield:IsCastable() and Target:IsSpellInRange(S.AvengersShield) and addonTable.config.Interrupt and (S.Rebuke:CooldownRemains() > 0.5 or S.HammerofJustice:CooldownRemains() > 0.5) then
	  if Cast(S.AvengersShield) then
      addonTable.cast("Avenger's Shield")
	    return "avengers_shield 1"
	  end
  end
end


local function EvaluateTargetIfFilterJudgment(TargetUnit)
  return TargetUnit:DebuffRemains(S.JudgmentDebuff)
end

local function MissingAura()
  return (Player:BuffDown(S.RetributionAura) and Player:BuffDown(S.DevotionAura) and Player:BuffDown(S.ConcentrationAura) and Player:BuffDown(S.CrusaderAura))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: devotion_aura
  if S.DevotionAura:IsCastable() and (MissingAura()) then
    if Cast(S.DevotionAura) then addonTable.cast("Devotion Aura") return "devotion_aura precombat 2"; end
  end
  -- lights_judgment
  if CDsON() and S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then addonTable.cast("Light's Judgment") return "lights_judgment precombat 4"; end
  end
  -- arcane_torrent
  if CDsON() and S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then addonTable.cast("Arcane Torrent") return "arcane_torrent precombat 6"; end
  end
  -- consecration
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(8) then
    if Cast(S.Consecration) then addonTable.cast("Consecration") return "consecration precombat 8"; end
  end
  -- variable,name=trinket_sync_slot,value=1,if=trinket.1.has_cooldown&trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)|!trinket.2.has_cooldown
  -- variable,name=trinket_sync_slot,value=2,if=trinket.2.has_cooldown&trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)|!trinket.1.has_cooldown
  -- Note: Unable to handle these trinket conditionals.
  -- Manually added: avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then addonTable.cast("Avenger's Shield") return "avengers_shield precombat 10"; end
  end
  -- Manually added: judgment
  if S.Judgment:IsReady() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then addonTable.cast("Judgment") return "judgment precombat 12"; end
  end
end

local function Defensives()
  if Player:HealthPercentage() <= Settings.Protection.LoHHP and S.LayonHands:IsCastable() then
    if Cast(S.LayonHands, nil, Settings.Protection.DisplayStyle.Defensives) then addonTable.cast("Layon Hands") return "lay_on_hands defensive 2"; end
  end
  if S.GuardianofAncientKings:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.GoAKHP and Player:BuffDown(S.ArdentDefenderBuff)) then
    if Cast(S.GuardianofAncientKings, nil, Settings.Protection.DisplayStyle.Defensives) then addonTable.cast("Guardian of Ancient Kings") return "guardian_of_ancient_kings defensive 4"; end
  end
  if S.ArdentDefender:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.ArdentDefenderHP and Player:BuffDown(S.GuardianofAncientKingsBuff)) then
    if Cast(S.ArdentDefender, nil, Settings.Protection.DisplayStyle.Defensives) then addonTable.cast("Ardent Defender") return "ardent_defender defensive 6"; end
  end
  if S.WordofGlory:IsReady() and (Player:HealthPercentage() <= Settings.Protection.PrioSelfWordofGloryHP and not Player:HealingAbsorbed()) then
    -- cast word of glory on us if it's a) free or b) probably not going to drop sotr
    if (Player:BuffRemains(S.ShieldoftheRighteousBuff) >= 5 or Player:BuffUp(S.DivinePurposeBuff) or Player:BuffUp(S.ShiningLightFreeBuff)) then
      if Cast(S.WordofGlory) then addonTable.cast("Word of Glory") return "word_of_glory defensive 8"; end
    else
      -- cast it anyway but run the fuck away
      if HR.CastAnnotated(S.WordofGlory, false, "KITE") then return "word_of_glory defensive 10"; end
    end
  end
  if S.ShieldoftheRighteous:IsReady() and (Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Protection.SotRHP)) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then addonTable.cast("Shield of the Righteous") return "shield_of_the_righteous defensive 14"; end
  end
end

local function Cooldowns()
  -- avengers_shield,if=time=0&set_bonus.tier29_2pc
  -- Note: Not handling anything at time=0
  -- lights_judgment,if=spell_targets.lights_judgment>=2|!raid_event.adds.exists|raid_event.adds.in>75|raid_event.adds.up
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then addonTable.cast("Light's Judgment") return "lights_judgment cooldowns 2"; end
  end
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if Cast(S.AvengingWrath, Settings.Protection.OffGCDasOffGCD.AvengingWrath) then addonTable.cast("Avenging Wrath") return "avenging_wrath cooldowns 4"; end
  end
  -- Manually added: sentinel
  -- Note: Simc has back-end code for Protection Paladin to replace AW with Sentinel when talented.
  if S.Sentinel:IsCastable() then
    if Cast(S.Sentinel, Settings.Protection.OffGCDasOffGCD.Sentinel) then addonTable.cast("Sentinel") return "sentinel cooldowns 6"; end
  end
  -- potion,if=buff.avenging_wrath.up
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvengingWrathBuff)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldowns 8"; end
    end
  end
  -- moment_of_glory,if=(buff.avenging_wrath.remains<15|(time>10|(cooldown.avenging_wrath.remains>15))&(cooldown.avengers_shield.remains&cooldown.judgment.remains&cooldown.hammer_of_wrath.remains))
  if S.MomentofGlory:IsCastable() and (Player:BuffRemains(S.AvengingWrathBuff) < 15 or (HL.CombatTime() > 10 or (S.AvengingWrath:CooldownRemains() > 15)) and (S.AvengersShield:CooldownDown() and S.Judgment:CooldownDown() and S.HammerofWrath:CooldownDown())) then
    if Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentOfGlory) then addonTable.cast("Moment of Glory") return "moment_of_glory cooldowns 10"; end
  end
  -- divine_toll,if=spell_targets.shield_of_the_righteous>=3
  if CDsON() and S.DivineToll:IsCastable() and (EnemiesCount8y >= 3) then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.Signature) then addonTable.cast("Divine Toll") return "divine_toll cooldowns 12"; end
  end
  -- bastion_of_light,if=buff.avenging_wrath.up|cooldown.avenging_wrath.remains<=30
  if S.BastionofLight:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or S.AvengingWrath:CooldownRemains() <= 30) then
    if Cast(S.BastionofLight, Settings.Protection.OffGCDasOffGCD.BastionOfLight) then addonTable.cast("Bastion of Light") return "bastion_of_light cooldowns 14"; end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.avenging_wrath.up
  -- Note: Not handling external buffs.
  -- fireblood,if=buff.avenging_wrath.remains>8
  if S.Fireblood:IsCastable() and (Player:BuffRemains(S.AvengingWrathBuff) > 8) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then addonTable.cast("Fireblood") return "fireblood cooldowns 16"; end
  end
end

local function Standard()
  -- consecration,if=buff.sanctification.stack=buff.sanctification.max_stack
  if S.Consecration:IsCastable() and (Player:BuffStack(S.SanctificationBuff) == VarSanctificationMaxStack) then
    if Cast(S.Consecration) then addonTable.cast("Consecration") return "consecration standard 2"; end
  end
  -- shield_of_the_righteous,if=(((!talent.righteous_protector.enabled|cooldown.righteous_protector_icd.remains=0)&holy_power>2)|buff.bastion_of_light.up|buff.divine_purpose.up)&(!buff.sanctification.up|buff.sanctification.stack<buff.sanctification.max_stack)
  -- TODO: Find a way to track RighteousProtector ICD.
  if S.ShieldoftheRighteous:IsReady() and ((Player:HolyPower() > 2 or Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.DivinePurposeBuff)) and (Player:BuffDown(S.SanctificationBuff) or Player:BuffStack(S.SanctificationBuff) < VarSanctificationMaxStack)) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.ShieldOfTheRighteous) then addonTable.cast("Shield of the Righteous") return "shield_of_the_righteous standard 4"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=spell_targets.shield_of_the_righteous>3&buff.bulwark_of_righteous_fury.stack>=3&holy_power<3
  if S.Judgment:IsReady() and (EnemiesCount8y > 3 and Player:BuffStack(S.BulwarkofRighteousFuryBuff) >= 3 and Player:HolyPower() < 3) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then addonTable.cast("Judgment") return "judgment standard 6"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=!buff.sanctification_empower.up&set_bonus.tier31_2pc
  if S.Judgment:IsReady() and (Player:BuffDown(S.SanctificationEmpowerBuff) and Player:HasTier(31, 2)) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then addonTable.cast("Judgment") return "judgment standard 8"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then addonTable.cast("Hammer of Wrath") return "hammer_of_wrath standard 10"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=charges>=2|full_recharge_time<=gcd.max
  if S.Judgment:IsReady() and (S.Judgment:Charges() >= 2 or S.Judgment:FullRechargeTime() <= Player:GCD() + 0.25) then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then addonTable.cast("Judgment") return "judgment standard 12"; end
  end
  -- avengers_shield,if=spell_targets.avengers_shield>2|buff.moment_of_glory.up
  if S.AvengersShield:IsCastable() and (EnemiesCount8y > 2 or Player:BuffUp(S.MomentofGloryBuff)) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then addonTable.cast("Avenger's Shield") return "avengers_shield standard 14"; end
  end
  -- divine_toll,if=(!raid_event.adds.exists|raid_event.adds.in>10)
  if CDsON() and S.DivineToll:IsReady() then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(30)) then addonTable.cast("Divine Toll") return "divine_toll standard 16"; end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then addonTable.cast("Avenger's Shield") return "avengers_shield standard 18"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastTargetIf(S.Judgment, Enemies30y, "min", EvaluateTargetIfFilterJudgment, nil, not Target:IsSpellInRange(S.Judgment)) then addonTable.cast("Judgment") return "judgment standard 20"; end
  end
  -- consecration,if=!consecration.up&(!buff.sanctification.stack=buff.sanctification.max_stack|!set_bonus.tier31_2pc)
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff) and (Player:BuffStack(S.SanctificationBuff) ~= VarSanctificationMaxStack or not Player:HasTier(31, 2))) then
    if Cast(S.Consecration) then addonTable.cast("Consecration") return "consecration standard 22"; end
  end
  -- eye_of_tyr,if=talent.inmost_light.enabled&raid_event.adds.in>=45|spell_targets.shield_of_the_righteous>=3
  if CDsON() and S.EyeofTyr:IsCastable() and (S.InmostLight:IsAvailable() or EnemiesCount8y >= 3) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Eye of Tyr") return "eye_of_tyr standard 24"; end
  end
  -- blessed_hammer
  if S.BlessedHammer:IsCastable() then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then addonTable.cast("Blessed Hammer") return "blessed_hammer standard 26"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then addonTable.cast("Hammer of the Righteous") return "hammer_of_the_righteous standard 28"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then addonTable.cast("Crusader Strike") return "crusader_strike standard 30"; end
  end
  -- eye_of_tyr,if=!talent.inmost_light.enabled&raid_event.adds.in>=60|spell_targets.shield_of_the_righteous>=3
  if CDsON() and S.EyeofTyr:IsCastable() and (not S.InmostLight:IsAvailable() or EnemiesCount8y >= 3) then
    if Cast(S.EyeofTyr, Settings.Protection.GCDasOffGCD.EyeOfTyr, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Eye of Tyr") return "eye_of_tyr standard 32"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff)) then
    -- Is our health ok? Are we in a party with a wounded party member? Heal them instead.
    if Player:HealthPercentage() > 90 and Player:IsInParty() and not Player:IsInRaid() then
      for _, Char in pairs(Unit.Party) do
        if Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() <= 80 then
          if HR.CastAnnotated(S.WordofGlory, false, Char:Name()) then return "word_of_glory standard party 34"; end
        end
      end
      -- Nobody in the party needs it. We might as well heal ourselves for the extra block chance.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then addonTable.cast("Word of Glory") return "word_of_glory standard self 36"; end
    else
      -- We're either solo, in a raid, or injured. Heal ourselves.
      if Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordOfGlory) then addonTable.cast("Word of Glory") return "word_of_glory standard self 38"; end
    end
  end
  -- arcane_torrent,if=holy_power<5
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:HolyPower() < 5) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then addonTable.cast("Arcane Torrent") return "arcane_torrent standard 40"; end
  end
  -- consecration,if=!buff.sanctification_empower.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.SanctificationEmpowerBuff)) then
    if Cast(S.Consecration) then addonTable.cast("Consecration") return "consecration standard 42"; end
  end
end

local function Trinkets()
  -- use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(buff.avenging_wrath.up|fight_remains<=40)|(variable.trinket_sync_slot=2&(!trinket.2.cooldown.ready|!buff.avenging_wrath.up))|!variable.trinket_sync_slot)
  -- use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(buff.avenging_wrath.up|fight_remains<=40)|(variable.trinket_sync_slot=1&(!trinket.1.cooldown.ready|!buff.avenging_wrath.up))|!variable.trinket_sync_slot)
  -- Note: Unable to handle these trinket conditionals. Using a generic fallback instead.
  -- use_items,if=buff.avenging_wrath.up|fight_remains<=40
  if Player:BuffUp(S.AvengingWrathBuff) or FightRemains <= 40 then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

-- APL Main
local function APL()
addonTable.resetPixels()
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  Enemies30y = Player:GetEnemiesInRange(30)
  if (AoEON()) then
    EnemiesCount8y = #Enemies8y
    EnemiesCount30y = #Enemies30y
  else
    EnemiesCount8y = 1
    EnemiesCount30y = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

    if addonTable.config.Interrupt then
      local ShouldReturn = Interrupt()
      if ShouldReturn then
        return ShouldReturn
      end
    end

    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.Rebuke, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives!
    if IsTanking then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard
    local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pool, if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

-- Define a function to call HR.CmdHandler arguments
local function ToggleCDs()
  HR.CmdHandler("cds")
end
local function ToggleAoE()
  HR.CmdHandler("aoe")
end
local function ToggleHeroRotation()
  HR.CmdHandler("toggle")
end

local function Init()
  local cdsButton = CreateFrame("Button", "ToggleCDsButton", UIParent, "SecureActionButtonTemplate")
  cdsButton:SetScript("OnClick", ToggleCDs)
   
  local aoeButton = CreateFrame("Button", "ToggleAoEButton", UIParent, "SecureActionButtonTemplate")
  aoeButton:SetScript("OnClick", ToggleAoE)
  
  local toggleButton = CreateFrame("Button", "ToggleHeroRotationButton", UIParent, "SecureActionButtonTemplate")
  toggleButton:SetScript("OnClick", ToggleHeroRotation)
  
  -- Clear keybinds for the selected keys below
  SetBinding("T")
  SetBinding("Y")
  SetBinding("U")
  
  
  -- Register the functions with keybindings
  -- You can change "T", "Y", and "U" to your desired key combinations
  SetBindingClick("T", "ToggleCDsButton")
  SetBindingClick("Y", "ToggleAoEButton")
  SetBindingClick("U", "ToggleHeroRotationButton")
  
  SaveBindings(GetCurrentBindingSet())

  HR.Print("Protection Paladin rotation has been updated for patch 10.2.7.")
end

HR.SetAPL(66, APL, Init)
