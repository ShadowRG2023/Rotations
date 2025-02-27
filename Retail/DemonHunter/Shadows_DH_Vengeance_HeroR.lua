--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local Item          = HL.Item

local settings = {
  Interrupt = true,
  Nova = true,
  Veng = false,
}
addonTable:SetConfig(settings)

addonTable.newMacro("OptiAction1", "INV_MISC_QUESTIONMARK", "/cast [@player] Sigil of Flame")
addonTable.newMacro("OptiAction2", "INV_MISC_QUESTIONMARK", "/cast [@player] Sigil of Misery")
addonTable.newMacro("OptiAction3", "INV_MISC_QUESTIONMARK", "/cast [@cursor] Sigil of Silence")
addonTable.newMacro("OptiAction4", "INV_MISC_QUESTIONMARK", "/cast [@cursor] Sigil of Chains")
addonTable.newMacro("OptiAction5", "INV_MISC_QUESTIONMARK", "/cast [@cursor] Metamorphosis")
addonTable.newMacro("OptiAction6", "INV_MISC_QUESTIONMARK", "/cast [@player] Elysian Decree")
addonTable.newMacro("OptiAction7", "INV_MISC_QUESTIONMARK", "/cast [@player] Infernal Strike")

-- DO NOT REMOVE 
addonTable.spells = {
  { spell = "MACRO OptiAction1", name = "SigilofFlame" },
  { spell = "MACRO OptiAction2", name = "SigilofMisery" },
  { spell = "MACRO OptiAction3", name = "SigilofSilence" },
  { spell = "MACRO OptiAction4", name = "SigilofChains" },
  { spell = "MACRO OptiAction5", name = "Metamorphosis" },
  { spell = "MACRO OptiAction6", name = "ElysianDecree" },
  { spell = "MACRO OptiAction7", name = "InfernalStrike" },
  { spell = "SPELL Throw Glaive", name = "Throw Glaive" },
  { spell = "SPELL The Hunt", name = "The Hunt" },
  { spell = "SPELL Spirit Bomb", name = "Spirit Bomb" },
  { spell = "SPELL Soul Cleave", name = "Soul Cleave" },
  { spell = "SPELL Soul Carver", name = "Soul Carver" },
  { spell = "SPELL Shear", name = "Shear" },
  { spell = "SPELL Immolation Aura", name = "Immolation Aura" },
  { spell = "SPELL Fracture", name = "Fracture" },
  { spell = "SPELL Fiery Brand", name = "Fiery Brand" },
  { spell = "SPELL Felblade", name = "Felblade" },
  { spell = "SPELL Fel Devastation", name = "Fel Devastation" },
  { spell = "SPELL Demon Spikes", name = "Demon Spikes" },
  { spell = "SPELL Bulk Extraction", name = "Bulk Extraction" },
-- INTERRUPTS
  { spell = "SPELL Disrupt", name = "Disrupt" },
  { spell = "SPELL Chaos Nova", name = "Chaos Nova" },
-- DO NOT REMOVE
--{ spell = "SPELL Sigil of Flame", name = "Sigil of Flame" },
--{ spell = "SPELL Sigil of Misery", name = "Sigil of Misery" },
--{ spell = "SPELL Sigil of Silence", name = "Sigil of Silence" },
--{ spell = "SPELL Sigil of Chains", name = "Sigil of Chains" },
--{ spell = "SPELL Elysian Decree", name = "Elysian Decree" },
--{ spell = "SPELL Metamorphosis", name = "Metamorphosis" },
--{ spell = "SPELL Infernal Strike", name = "Infernal Strike" },
}
-- DO NOT REMOVE ^
addonTable.mapKeybinds(addonTable.spells)

-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastSuggested = HR.CastSuggested
local CastAnnotated = HR.CastAnnotated
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- File locals
local DemonHunter   = HR.Commons.DemonHunter
-- lua
local GetTime       = GetTime
local mathmax       = math.max
local mathmin       = math.min
local tableinsert   = table.insert

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Vengeance
local I = Item.DemonHunter.Vengeance

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.Item:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  CommonsDS = HR.GUISettings.APL.DemonHunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DemonHunter.CommonsOGCD,
  Vengeance = HR.GUISettings.APL.DemonHunter.Vengeance
}

-- Rotation Var
local SoulFragments, TotalSoulFragments, IncSoulFragments
local VarEDFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
local SigilPopTime = (S.QuickenedSigils:IsAvailable()) and 1 or 2
local IsInMeleeRange, IsInAoERange
local ActiveMitigationNeeded
local IsTanking
local Enemies8yMelee
local EnemiesCount8yMelee
local VarDontCleave, VarFDReady, VarST, VarSmallAoE, VarBigAoE, VarCanSpB
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarEDFragments = (S.SoulSigils:IsAvailable()) and 4 or 3
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

-- Melee Is In Range w/ Movement Handlers
local function UpdateIsInMeleeRange()
  if S.Felblade:TimeSinceLastCast() < Player:GCD()
  or S.InfernalStrike:TimeSinceLastCast() < Player:GCD() then
    IsInMeleeRange = true
    IsInAoERange = true
    return
  end

  IsInMeleeRange = Target:IsInMeleeRange(5)
  IsInAoERange = IsInMeleeRange or EnemiesCount8yMelee > 0
end
-- Interrupts
local function Interrupt()
	if Target:IsInterruptible() then
		if S.Disrupt:IsCastable() and Target:IsSpellInRange(S.Disrupt) and addonTable.config.Interrupt then
			if Cast(S.Disrupt) then
				addonTable.cast("Disrupt")
				return "disrupt 1"
			end
		end

    if S.FelEruption:IsAvailable() then
      if S.FelEruption:IsCastable() and Target:IsSpellInRange(S.FelEruption) and addonTable.config.Stun and S.Disrupt:CooldownRemains() > 0.5 then
			  if Cast(S.FelEruption) then
				  addonTable.cast("Fel Eruption")
				  return "feleruption 1"
			  end
		  end
    end

    if S.ChaosNova:IsCastable() and Target:IsSpellInRange(S.ChaosNova) and addonTable.config.Nova and S.Disrupt:CooldownRemains() > 0.5 then
			if Cast(S.ChaosNova) then
				addonTable.cast("Chaos Nova")
				return "chaosnova 1"
			end
		end
	end
end
-- CastTargetIf/CastCycle functions
local function EvaluateTargetIfFilterFBRemains(TargetUnit)
  -- target_if=max:dot.fiery_brand.remains
  return (TargetUnit:DebuffRemains(S.FieryBrandDebuff))
end

local function EvaluateTargetIfFractureMaintenance(TargetUnit)
  -- if=dot.fiery_brand.ticking&buff.recrimination.up
  -- Note: RecriminationBuff check is done before CastTargetIf
  return (TargetUnit:DebuffUp(S.FieryBrandDebuff))
end

-- Base rotation functions
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- sigil_of_flame
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then addonTable.cast("Throw Glaive") return "throw_glaive precombat 9"; end
  end
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then addonTable.cast("Sigil of Flame") return "sigil_of_flame precombat 2"; end
  end
  -- Manually added: Gap closers
  if S.InfernalStrike:IsCastable() and IsInMeleeRange then
    if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then addonTable.cast("Infernal Strike") return "infernal_strike precombat 6"; end
  end
  if S.Felblade:IsCastable() and not IsInMeleeRange then
    if Cast(S.Felblade, nil, nil, not Target:IsInRange(15)) then addonTable.cast("Felblade") return "felblade precombat 5"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then addonTable.cast("Immolation Aura") return "immolation_aura precombat 4"; end
  end
  -- Manually added: First attacks
  if S.Fracture:IsCastable() and IsInMeleeRange then
    if Cast(S.Fracture) then addonTable.cast("Fracture") return "fracture precombat 8"; end
  end
  if S.Shear:IsCastable() and IsInMeleeRange then
    if Cast(S.Shear) then addonTable.cast("Shear") return "shear precombat 10"; end
  end
end

--[[--Going to make an opener more static
local function STOpener()
  if stuff here
    if cast that
  end
end  ]]

local function Defensives()
  -- Metamorphosis,if=!buff.metamorphosis.up|target.time_to_die<15
  if S.Metamorphosis:IsCastable() and Player:HealthPercentage() <= Settings.Vengeance.MetamorphosisHealthThreshold and (Player:BuffDown(S.MetamorphosisBuff) or Target:TimeToDie() < 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then addonTable.cast("Metamorphosis") return "metamorphosis defensives"; end
  end
  -- Fiery Brand
  if S.FieryBrand:IsCastable() and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.FieryBrandHealthThreshold) then
    if Cast(S.FieryBrand, nil, Settings.Vengeance.DisplayStyle.Defensives, not Target:IsSpellInRange(S.FieryBrand)) then addonTable.cast("Fiery Brand") return "fiery_brand defensives"; end
  end
end

local function Maintenance()
  -- Demon Spikes
  if S.DemonSpikes:IsCastable() and Player:BuffDown(S.DemonSpikesBuff) and Player:BuffDown(S.MetamorphosisBuff) and (EnemiesCount8yMelee == 1 and Player:BuffDown(S.FieryBrandDebuff) or EnemiesCount8yMelee > 1) then
    if S.DemonSpikes:ChargesFractional() > 1.9 then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.Defensives) then addonTable.cast("Demon Spikes") return "demon_spikes defensives (Capped)"; end
    elseif (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Vengeance.DemonSpikesHealthThreshold) then
      if Cast(S.DemonSpikes, nil, Settings.Vengeance.DisplayStyle.Defensives) then addonTable.cast("Demon Spikes") return "demon_spikes defensives (Danger)"; end
    end
  end
  -- fiery_brand,if=talent.fiery_brand&((active_dot.fiery_brand=0&(cooldown.sigil_of_flame.remains<=(execute_time+gcd.remains)|cooldown.soul_carver.remains<=(execute_time+gcd.remains)|cooldown.fel_devastation.remains<=(execute_time+gcd.remains)))|(talent.down_in_flames&full_recharge_time<=(execute_time+gcd.remains)))
  if S.FieryBrand:IsCastable() and ((S.FieryBrandDebuff:AuraActiveCount() == 0 and (S.SigilofFlame:CooldownRemains() <= (S.FieryBrand:ExecuteTime() + Player:GCDRemains()) or S.SoulCarver:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()) or S.FelDevastation:CooldownRemains() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()))) or (S.DowninFlames:IsAvailable() and S.FieryBrand:FullRechargeTime() < (S.FieryBrand:ExecuteTime() + Player:GCDRemains()))) then
    if Cast(S.FieryBrand, Settings.Vengeance.GCDasOffGCD.FieryBrand, nil, not Target:IsSpellInRange(S.FieryBrand)) then addonTable.cast("Fiery Brand") return "fiery_brand maintenance 2"; end
  end
  -- sigil_of_flame,if=talent.ascending_flame|(active_dot.sigil_of_flame=0&!in_flight)
  if S.SigilofFlame:IsCastable() and (S.AscendingFlame:IsAvailable() or (S.SigilofFlameDebuff:AuraActiveCount() == 0 and S.SigilofFlame:TimeSinceLastCast() > SigilPopTime)) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then addonTable.cast("Sigil of Flame") return "sigil_of_flame maintenance 4"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then addonTable.cast("Immolation Aura") return "immolation_aura maintenance 6"; end
  end
  -- bulk_extraction,if=((5-soul_fragments)<=spell_targets)&soul_fragments<=2
  if S.BulkExtraction:IsCastable() and (((5 - SoulFragments) <= EnemiesCount8yMelee) and SoulFragments <= 2) then
    if Cast(S.BulkExtraction, Settings.Vengeance.GCDasOffGCD.BulkExtraction, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Bulk Extraction") return "bulk_extraction maintenance 8"; end
  end
  -- spirit_bomb,if=variable.can_spb
  if VarNoMaintCleave and not VarCanSpB then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  if S.SpiritBomb:IsReady() and (VarCanSpB) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Spirit Bomb") return "spirit_bomb maintenance 10"; end
  end
  -- felblade,if=((!talent.spirit_bomb|active_enemies=1)&fury.deficit>=40)|((cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50)
  if S.Felblade:IsReady() and (((not S.SpiritBomb:IsAvailable() or EnemiesCount8yMelee ==1) and Player:FuryDeficit() >= 40) or ((S.FelDevastation:CooldownRemains() <= (S.Felblade:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then addonTable.cast("Felblade") return "felblade maintenance 12"; end
  end
  -- fracture,if=(cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50
  if S.Fracture:IsCastable() and ((S.FelDevastation:CooldownRemains() <= (S.Fracture:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50) then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then addonTable.cast("Fracture") return "fracture maintenance 14"; end
  end
  -- shear,if=(cooldown.fel_devastation.remains<=(execute_time+gcd.remains))&fury<50
  if S.Shear:IsCastable() and ((S.FelDevastation:CooldownRemains() <= (S.Fracture:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 50) then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then addonTable.cast("Shear") return "shear maintenance 16"; end
  end
  -- Manually added: This should cause a fraction of a second of wait time while SoulFragments for Spirit Bomb move from incoming to active.
  if Player:FuryDeficit() <= 30 and EnemiesCount8yMelee > 1 and TotalSoulFragments >= 4 and SoulFragments < 4 then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  -- spirit_bomb,if=fury.deficit<=30&spell_targets>1&soul_fragments>=4
  if S.SpiritBomb:IsReady() and (Player:FuryDeficit() <= 30 and EnemiesCount8yMelee > 1 and SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Spirit Bomb") return "spirit_bomb maintenance 18"; end
  end
  -- soul_cleave,if=fury.deficit<=40
  if S.SoulCleave:IsReady() and not VarNoMaintCleave and (Player:FuryDeficit() <= 40) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Cleave") return "soul_cleave maintenance 20"; end
  end
end

local function FieryDemise()
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura) then addonTable.cast("Immolation Aura") return "immolation_aura fiery_demise 2"; end
  end
  -- sigil_of_flame,if=talent.ascending_flame|active_dot.sigil_of_flame=0
  if S.SigilofFlame:IsCastable() and (S.AscendingFlame:IsAvailable() or S.SigilofFlameDebuff:AuraActiveCount() == 0) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then addonTable.cast("Sigil of Flame") return "sigil_of_flame fiery_demise 4"; end
  end
  -- felblade,if=(!talent.spirit_bomb|(cooldown.fel_devastation.remains<=(execute_time+gcd.remains)))&fury<50
  if S.Felblade:IsReady() and ((not S.SpiritBomb:IsAvailable() or (S.FelDevastation:CooldownRemains() <= (S.Felblade:ExecuteTime() + Player:GCDRemains()))) and Player:Fury() < 50) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then addonTable.cast("Felblade") return "felblade fiery_demise 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation fiery_demise 8"; end
  end
  -- soul_carver,if=soul_fragments.total<3
  if S.SoulCarver:IsCastable() and (TotalSoulFragments < 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Carver") return "soul_carver fiery_demise 10"; end
  end
  -- the_hunt
  if CDsON() then
    if S.TheHunt:IsCastable() then
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(50)) then addonTable.cast("The Hunt") return "the_hunt fiery_demise 12"; end
    end
    -- elysian_decree,if=fury>=40&!prev_gcd.1.elysian_decree
    if S.ElysianDecree:IsCastable() and (Player:Fury() >= 40 and not Player:PrevGCD(1, S.ElysianDecree)) then
      if Cast(S.ElysianDecree, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(30)) then addonTable.cast("Elysian Decree") return "elysian_decree fiery_demise 14"; end
    end
  end
  -- spirit_bomb,if=variable.can_spb
  if VarNoMaintCleave and not VarCanSpB then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  if S.SpiritBomb:IsReady() and (VarCanSpB) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Spirit Bomb") return "spirit_bomb fiery_demise 16"; end
  end
end

local function Filler()
  -- sigil_of_chains,if=talent.cycle_of_binding&talent.sigil_of_chains
  if S.SigilofChains:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofChains, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then addonTable.cast("Sigil of Chains") return "sigil_of_chains filler 2"; end
  end
  -- sigil_of_misery,if=talent.cycle_of_binding&talent.sigil_of_misery.enabled
  if S.SigilofMisery:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofMisery, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then addonTable.cast("Sigil of Misery") return "sigil_of_misery filler 4"; end
  end
  -- sigil_of_silence,if=talent.cycle_of_binding&talent.sigil_of_silence.enabled
  if S.SigilofSilence:IsCastable() and (S.CycleofBinding:IsAvailable()) then
    if Cast(S.SigilofSilence, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then addonTable.cast("Sigil of Silence") return "sigil_of_silence filler 6"; end
  end
  -- felblade
  if S.Felblade:IsReady() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then addonTable.cast("Felblade") return "felblade filler 8"; end
  end
  -- shear
  if S.Shear:IsCastable() then
    if Cast(S.Shear, nil, nil, not IsInMeleeRange) then addonTable.cast("Shear") return "shear filler 10"; end
  end
  -- throw_glaive
  if S.ThrowGlaive:IsCastable() then
    if Cast(S.ThrowGlaive, nil, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then addonTable.cast("Throw Glaive") return "throw_glaive filler 12"; end
  end
end

local function SingleTarget()
  -- the_hunt
  if CDsON() then
    if S.TheHunt:IsCastable() then
      if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(50)) then addonTable.cast("The Hunt") return "the_hunt single_target 2"; end
    end
    -- elysian_decree,if=!prev_gcd.1.elysian_decree
    if S.ElysianDecree:IsCastable() and (not Player:PrevGCD(1, S.ElysianDecree)) then
      if Cast(S.ElysianDecree, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(30)) then addonTable.cast("Elysian Decree") return "elysian_decree single_target 8"; end
    end
  end
  -- soul_carver
  if S.SoulCarver:IsCastable() then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Carver") return "soul_carver single_target 4"; end
  end
  -- fel_devastation,if=talent.collective_anguish|(talent.stoke_the_flames&talent.burning_blood)
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or (S.StoketheFlames:IsAvailable() and S.BurningBlood:IsAvailable())) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation single_target 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation single_target 10"; end
  end
  -- soul_cleave,if=!variable.dont_cleave
  if S.SoulCleave:IsReady() and (not VarDontCleave) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Cleave") return "soul_cleave single_target 12"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then addonTable.cast("Fracture") return "fracture single_target 14"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function SmallAoE()
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(50)) then addonTable.cast("The Hunt") return "the_hunt small_aoe 2"; end
  end
  -- fel_devastation,if=talent.collective_anguish.enabled|(talent.stoke_the_flames.enabled&talent.burning_blood.enabled)
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or (S.StoketheFlames:IsAvailable() and S.BurningBlood:IsAvailable())) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation small_aoe 4"; end
  end
  -- elysian_decree,if=fury>=40&(soul_fragments.total<=1|soul_fragments.total>=4)&!prev_gcd.1.elysian_decree
  if S.ElysianDecree:IsCastable() and (Player:Fury() >= 40 and (TotalSoulFragments <= 1 or TotalSoulFragments >= 4) and not Player:PrevGCD(1, S.ElysianDecree)) then
    if Cast(S.ElysianDecree, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(30)) then addonTable.cast("Elysian Decree") return "elysian_decree small_aoe 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation small_aoe 8"; end
  end
  -- soul_carver,if=soul_fragments.total<3
  if S.SoulCarver:IsCastable() and (TotalSoulFragments < 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Carver") return "soul_carver small_aoe 10"; end
  end
  -- soul_cleave,if=(soul_fragments<=1|!talent.spirit_bomb)&!variable.dont_cleave
  if S.SoulCleave:IsReady() and ((SoulFragments <= 1 or not S.SpiritBomb:IsAvailable()) and not VarDontCleave) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Cleave") return "soul_cleave small_aoe 14"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then addonTable.cast("Fracture") return "fracture small_aoe 16"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function BigAoE()
  -- fel_devastation,if=talent.collective_anguish|talent.stoke_the_flames
  if S.FelDevastation:IsReady() and (S.CollectiveAnguish:IsAvailable() or S.StoketheFlames:IsAvailable()) then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation big_aoe 2"; end
  end
  -- the_hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(50)) then addonTable.cast("The Hunt") return "the_hunt big_aoe 4"; end
  end
  -- elysian_decree,if=fury>=40&(soul_fragments.total<=1|soul_fragments.total>=4)&!prev_gcd.1.elysian_decree
  if S.ElysianDecree:IsCastable() and (Player:Fury() >= 40 and (TotalSoulFragments <= 1 or TotalSoulFragments >= 4) and not Player:PrevGCD(1, S.ElysianDecree)) then
    if Cast(S.ElysianDecree, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(30)) then addonTable.cast("Elysian Decree") return "elysian_decree big_aoe 6"; end
  end
  -- fel_devastation
  if S.FelDevastation:IsReady() then
    if Cast(S.FelDevastation, Settings.Vengeance.GCDasOffGCD.FelDevastation, nil, not Target:IsInMeleeRange(20)) then addonTable.cast("Fel Devastation") return "fel_devastation big_aoe 8"; end
  end
  -- soul_carver,if=soul_fragments.total<3
  if S.SoulCarver:IsCastable() and (TotalSoulFragments < 3) then
    if Cast(S.SoulCarver, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Carver") return "soul_carver big_aoe 10"; end
  end
  -- Manually added: This should cause a fraction of a second of wait time while SoulFragments for Spirit Bomb move from incoming to active.
  if TotalSoulFragments >= 4 and SoulFragments < 4 then
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Spirit Bomb"; end
  end
  -- spirit_bomb,if=soul_fragments>=4
  if S.SpiritBomb:IsReady() and (SoulFragments >= 4) then
    if Cast(S.SpiritBomb, nil, nil, not Target:IsInMeleeRange(8)) then addonTable.cast("Spirit Bomb") return "spirit_bomb big_aoe 12"; end
  end
  -- soul_cleave,if=!talent.spirit_bomb&!variable.dont_cleave
  if S.SoulCleave:IsReady() and (not S.SpiritBomb:IsAvailable() or not VarDontCleave) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Cleave") return "soul_cleave big_aoe 14"; end
  end
  -- fracture
  if S.Fracture:IsCastable() then
    if Cast(S.Fracture, nil, nil, not IsInMeleeRange) then addonTable.cast("Fracture") return "fracture big_aoe 16"; end
  end
  -- soul_cleave,if=!variable.dont_cleave
  if S.SoulCleave:IsReady() and (not VarDontCleave) then
    if Cast(S.SoulCleave, nil, nil, not IsInMeleeRange) then addonTable.cast("Soul Cleave") return "soul_cleave big_aoe 18"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function Externals()
  -- invoke_external_buff,name=symbol_of_hope
  -- invoke_external_buff,name=power_infusion
end

-- APL Main
local function APL()
addonTable.resetPixels()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8)
  if (AoEON()) then
    EnemiesCount8yMelee = #Enemies8yMelee
  else
    EnemiesCount8yMelee = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
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
      FightRemains = HL.FightRemains(Enemies8yMelee, false)
    end

    -- Update Soul Fragment Totals
    --UpdateSoulFragments()
    SoulFragments = DemonHunter.Souls.AuraSouls
    IncSoulFragments = DemonHunter.Souls.IncomingSouls
    TotalSoulFragments = SoulFragments + IncSoulFragments

    -- Update if target is in melee range
    UpdateIsInMeleeRange()

    -- Set Tanking Variables
    ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
    IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=fd_ready,value=talent.fiery_brand&talent.fiery_demise&active_dot.fiery_brand>0
    VarFDReady = S.FieryBrand:IsAvailable() and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0
    -- variable,name=dont_cleave,value=(cooldown.fel_devastation.remains<=(action.soul_cleave.execute_time+gcd.remains))&fury<80
    -- Note: Moved below VarST/VarSmallAoE/VarBigAoE definitions, as we've manually added a VarST check
    -- variable,name=single_target,value=spell_targets.spirit_bomb=1
    VarST = EnemiesCount8yMelee == 1
    -- variable,name=small_aoe,value=spell_targets.spirit_bomb>=2&spell_targets.spirit_bomb<=5
    VarSmallAoE = EnemiesCount8yMelee >= 2 and EnemiesCount8yMelee <= 5
    -- variable,name=big_aoe,value=spell_targets.spirit_bomb>=6
    VarBigAoE = EnemiesCount8yMelee >= 6
    -- Note: Below line moved from above.
    VarDontCleave = ((S.FelDevastation:CooldownRemains() <= (S.SoulCleave:ExecuteTime() + Player:GCDRemains())) and Player:Fury() < 80 or (IncSoulFragments > 1 or TotalSoulFragments >= 5) and not VarST)
    -- variable,name=can_spb,op=setif,condition=variable.fd_ready,value=(variable.single_target&soul_fragments>=5)|(variable.small_aoe&soul_fragments>=4)|(variable.big_aoe&soul_fragments>=3),value_else=(variable.small_aoe&soul_fragments>=4)|(variable.big_aoe&soul_fragments>=3)
    if VarFDReady then
      VarCanSpB = (VarST and SoulFragments >= 5) or (VarSmallAoE and SoulFragments >= 4) or (VarBigAoE and SoulFragments >= 3)
    else
      VarCanSpB = (VarSmallAoE and SoulFragments >= 4) or (VarBigAoE and SoulFragments >= 3)
    end
    -- Note: Manually added variable for holding maintenance SoulCleave if incoming souls would make VarCanSpB true
    if VarFDReady then
      VarNoMaintCleave = (VarST and TotalSoulFragments >= 5) or (VarSmallAoE and TotalSoulFragments >= 4) or (VarBigAoE and TotalSoulFragments >= 3)
    else
      VarNoMaintCleave = (VarSmallAoE and TotalSoulFragments >= 5) or (VarBigAoE and TotalSoulFragments >= 4)
    end
    -- auto_attack
    -- disrupt,if=target.debuff.casting.react (Interrupts)
   -- local ShouldReturn = Everyone.Interrupt(S.Disrupt, Settings.CommonsDS.DisplayStyle.Interrupts, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- infernal_strike,use_off_gcd=1
    if S.InfernalStrike:IsCastable() and (not Settings.Vengeance.ConserveInfernalStrike or S.InfernalStrike:ChargesFractional() > 1.9) and (S.InfernalStrike:TimeSinceLastCast() > 2) and IsInMeleeRange then
      if Cast(S.InfernalStrike, Settings.Vengeance.OffGCDasOffGCD.InfernalStrike, nil, not Target:IsInRange(30)) then addonTable.cast("Infernal Strike") return "infernal_strike main 2"; end
    end
    -- demon_spikes,use_off_gcd=1,if=!buff.demon_spikes.up&!cooldown.pause_action.remains
    -- Note: Handled via Defensives()
    -- metamorphosis,use_off_gcd=1,if=!buff.metamorphosis.up&cooldown.fel_devastation.remains>12
    if S.Metamorphosis:IsCastable() and (Player:BuffDown(S.MetamorphosisBuff) and S.FelDevastation:CooldownRemains() > 12) then
      if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis) then addonTable.cast("Metamorphosis") return "metamorphosis main 4"; end
    end
    -- potion,use_off_gcd=1
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- call_action_list,name=externals
    -- Note: Not handling externals
    -- local ShouldReturn = Externals(); if ShouldReturn then return ShouldReturn; end
    -- use_items,use_off_gcd=1
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
    -- call_action_list,name=fiery_demise,if=talent.fiery_brand&talent.fiery_demise&active_dot.fiery_brand>0
    if S.FieryBrand:IsAvailable() and S.FieryDemise:IsAvailable() and S.FieryBrandDebuff:AuraActiveCount() > 0 then
      local ShouldReturn = FieryDemise(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=maintenance
    local ShouldReturn = Maintenance(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=single_target,if=variable.single_target
    if VarST then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SingleTarget()"; end
    end
    -- run_action_list,name=small_aoe,if=variable.small_aoe
    if VarSmallAoE then
      local ShouldReturn = SmallAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SmallAoE()"; end
    end
    -- run_action_list,name=big_aoe,if=variable.big_aoe
    if VarBigAoE then
      local ShouldReturn = BigAoE(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Wait for BigAoE()"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

--[[
SHADOW'S CODE FOR INTERRUPTS AND KEYBIND TOGGLES
FOR AUTO INTERRUPTS ENSURE TO PUT THIS CODE DIRECTLY UNDER: if Everyone.TargetIsValid() or Player:AffectingCombat() then
  if addonTable.config.Interrupt then
	  local ShouldReturn = Interrupt()
		if ShouldReturn then
			return ShouldReturn
		end
	end   
]]--

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
  S.FieryBrandDebuff:RegisterAuraTracking()
  S.SigilofFlameDebuff:RegisterAuraTracking()

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

  HR.Print("Vengeance Demon Hunter rotation has been updated for patch 10.2.7.")
end

HR.SetAPL(581, APL, Init);
