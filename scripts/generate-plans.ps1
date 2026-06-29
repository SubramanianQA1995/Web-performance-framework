# =====================================================================
# generate-plans.ps1  (WEB framework)
# Derives EndToEnd/Load/Stress/Spike/Soak from the validated browser
# journey inside SmokeTest.jmx. The journey (4 page transactions +
# embedded resources + correlation + sync timer + assertions) is authored
# ONCE in SmokeTest.jmx; here we only swap the Thread Group(s).
#   pwsh ./scripts/generate-plans.ps1
# =====================================================================
$ErrorActionPreference = 'Stop'
$jmxDir = Join-Path $PSScriptRoot '..\jmx'
$src    = Join-Path $jmxDir 'SmokeTest.jmx'

function TG($name,$threads,$ramp,$delay,$dur,$loopForever,$loops) { @"
<ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="$name" enabled="true">
  <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
  <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
    <boolProp name="LoopController.continue_forever">$loopForever</boolProp>
    <stringProp name="LoopController.loops">$loops</stringProp>
  </elementProp>
  <stringProp name="ThreadGroup.num_threads">$threads</stringProp>
  <stringProp name="ThreadGroup.ramp_time">$ramp</stringProp>
  <boolProp name="ThreadGroup.scheduler">$(if($dur){'true'}else{'false'})</boolProp>
  <stringProp name="ThreadGroup.duration">$dur</stringProp>
  <stringProp name="ThreadGroup.delay">$delay</stringProp>
</ThreadGroup>
"@ }

# E2E: single thorough journey, no scheduler (loops N times)
$tgE2E    = @( (TG 'TG - E2E Journey' '${__P(e2e_users,1)}' '${__P(e2e_rampup,1)}' '' '' 'false' '${__P(e2e_loops,1)}') )

# Load: steady state
$tgLoad   = @( (TG 'TG - Web Load (steady state)' '${__P(users,20)}' '${__P(rampup,60)}' '${__P(startup_delay,0)}' '${__P(duration,300)}' 'true' '-1') )

# Stress: progressive climb (web pages are heavier -> smaller steps)
$tgStress = @(
  (TG 'TG - Stress Step 1' '${__P(stress_s1_users,20)}'  '${__P(stress_s1_ramp,60)}'  '0'                        '${__P(stress_s1_dur,900)}' 'true' '-1'),
  (TG 'TG - Stress Step 2' '${__P(stress_s2_users,50)}'  '${__P(stress_s2_ramp,60)}'  '${__P(stress_s2_delay,180)}' '${__P(stress_s2_dur,720)}' 'true' '-1'),
  (TG 'TG - Stress Step 3' '${__P(stress_s3_users,100)}' '${__P(stress_s3_ramp,90)}'  '${__P(stress_s3_delay,360)}' '${__P(stress_s3_dur,540)}' 'true' '-1'),
  (TG 'TG - Stress Step 4' '${__P(stress_s4_users,200)}' '${__P(stress_s4_ramp,120)}' '${__P(stress_s4_delay,540)}' '${__P(stress_s4_dur,360)}' 'true' '-1')
)

# Spike: steady baseline + sudden on-sale bursts (raise spikeN_users on
# cloud; pair with -Jsync_group_size to make the burst hit seat-select together)
$tgSpike  = @(
  (TG 'TG - Spike Baseline' '${__P(spike_baseline_users,10)}' '${__P(spike_baseline_ramp,30)}' '0'                      '${__P(spike_duration,600)}' 'true' '-1'),
  (TG 'TG - Spike Burst 1'  '${__P(spike1_users,50)}'         '${__P(spike1_ramp,10)}'         '${__P(spike1_delay,120)}' '${__P(spike1_hold,60)}'     'true' '-1'),
  (TG 'TG - Spike Burst 2'  '${__P(spike2_users,100)}'        '${__P(spike2_ramp,15)}'         '${__P(spike2_delay,300)}' '${__P(spike2_hold,60)}'     'true' '-1')
)

# Soak: long steady
$tgSoak   = @( (TG 'TG - Web Soak (endurance)' '${__P(soak_users,20)}' '${__P(soak_rampup,120)}' '0' '${__P(soak_duration,1800)}' 'true' '-1') )

$plans = @{
  'EndToEndJourney.jmx' = @{ name='ITS Web - End To End Journey'; tgs=$tgE2E }
  'LoadTest.jmx'        = @{ name='ITS Web - Load Test';          tgs=$tgLoad }
  'StressTest.jmx'      = @{ name='ITS Web - Stress Test';        tgs=$tgStress }
  'SpikeTest.jmx'       = @{ name='ITS Web - Spike Test';         tgs=$tgSpike }
  'SoakTest.jmx'        = @{ name='ITS Web - Soak Test';          tgs=$tgSoak }
}

foreach ($file in $plans.Keys) {
  [xml]$doc = Get-Content $src -Raw
  $inner = $doc.SelectSingleNode('/jmeterTestPlan/hashTree/hashTree')
  $tg    = $inner.SelectSingleNode('ThreadGroup')
  $body  = $tg.NextSibling
  $bodyXml = $body.OuterXml
  [void]$inner.RemoveChild($tg)
  [void]$inner.RemoveChild($body)
  foreach ($tgXml in $plans[$file].tgs) {
    $fTg = $doc.CreateDocumentFragment(); $fTg.InnerXml = $tgXml; [void]$inner.AppendChild($fTg)
    $fBd = $doc.CreateDocumentFragment(); $fBd.InnerXml = $bodyXml; [void]$inner.AppendChild($fBd)
  }
  $doc.SelectSingleNode('/jmeterTestPlan/hashTree/TestPlan').SetAttribute('testname', $plans[$file].name)
  $doc.Save((Join-Path $jmxDir $file))
  Write-Host "Generated $file"
}
Write-Host "Done."
