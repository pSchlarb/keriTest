#!/bin/bash

source helpers.sh

rm workshop.env
rm *.log

echo "***Stopping old processes and starting VLEI-server***"
#region vleiServer
pid_file="vleiserver.pid"
cmd="vLEI-server  -s ./schemas/ -c /cache/acdc -o /cache/oobis"

if [ -f "$pid_file" ]; then
    pid=$(cat "$pid_file")
    if kill -0 $pid > /dev/null 2>&1; then
        echo "Process is already running with PID $pid. Killing it..."
        kill $pid
        kill $(cat witness.wan.pid)
        kill $(cat witness.warn.pid)
        kill $(cat witness.wes.pid)
        kill $(cat witness.wil.pid)
        kill $(cat witness.wiso.pid)
        kill $(cat witness.wums.pid)
    else
        echo "Stale PID file found, removing it."
        rm "$pid_file"
    fi
fi
echo "Starting : $cmd"
$cmd &
echo $! > $pid_file
#endregion

export CONFIG_DIR=kericonf
logEnv CONFIG_DIR $CONFIG_DIR

#region salts
echo "***Generating Salts***"
SALTWAN="$(kli salt)"
logEnv SALTWAN $SALTWAN
SALTWARN="$(kli salt)"
logEnv SALTWARN $SALTWARN
SALTWES="$(kli salt)"
logEnv SALTWES $SALTWES
SALTWIL="$(kli salt)"
logEnv SALTWIL $SALTWIL
SALTWISO="$(kli salt)"
logEnv SALTWISO $SALTWISO
SALTWUMS="$(kli salt)"
logEnv SALTWUMS $SALTWUMS
SALTBC="$(kli salt)"
logEnv SALTBC $SALTBC
SALTCC="$(kli salt)"
logEnv SALTCC $SALTCC
SALTAC="$(kli salt)"
logEnv SALTAC $SALTAC

echo "Salts generated"
echo "SALTWAN $SALTWAN"
echo "SALTWARN $SALTWARN"
echo "SALTWES $SALTWES"
echo "SALTWIL $SALTWIL"
echo "SALTWISO $SALTWISO"
echo "SALTWUMS $SALTWUMS"
echo "SALTBC $SALTBC"
echo "SALTCC $SALTCC"
echo "SALTAC $SALTAC"
#endregion


echo "***Clearing Keri Database and Keystores***"
#clear keri database and keystores!!!! Warning clears all keri data and keystores
rm -r /home/vscode/.keri

#region witness init
echo "***Initializing Witnesses***"
kli init --name wan --salt $SALTWAN --nopasscode --config-dir "${CONFIG_DIR}"     --config-file main/wan-witness
kli init --name warn --salt $SALTWARN --nopasscode --config-dir "${CONFIG_DIR}" --config-file main/warn-witness
kli init --name wes --salt $SALTWES --nopasscode --config-dir "${CONFIG_DIR}" --config-file main/wes-witness
kli init --name wil --salt $SALTWIL --nopasscode --config-dir "${CONFIG_DIR}" --config-file main/wil-witness
kli init --name wiso --salt $SALTWISO --nopasscode --config-dir "${CONFIG_DIR}" --config-file main/wiso-witness
kli init --name wums --salt $SALTWUMS --nopasscode --config-dir "${CONFIG_DIR}" --config-file main/wums-witness

#endregion


#region witness start
echo "***Starting Witnesses***"
witnessLog "#region witness start"
kli witness start --name wan --alias wan  -T 5631  -H 5641  --config-dir $CONFIG_DIR  --config-file wan-witness --loglevel DEBUG 2>>  bwan.log &
echo $! > witness.wan.pid
kli witness start --name warn --alias warn -T 5632  -H 5642  --config-dir $CONFIG_DIR  --config-file warn-witness --loglevel DEBUG 2>>  bwarn.log &
echo $! > witness.warn.pid
kli witness start --name wes --alias wes -T 5633  -H 5643  --config-dir $CONFIG_DIR  --config-file wes-witness  --loglevel DEBUG 2>>  cwes.log &
echo $! > witness.wes.pid
kli witness start --name wil --alias wil -T 5634  -H 5644  --config-dir $CONFIG_DIR  --config-file wil-witness  --loglevel DEBUG 2>> cwil.log &
echo $! > witness.wil.pid
kli witness start --name wiso --alias wiso -T 5635  -H 5645  --config-dir $CONFIG_DIR  --config-file wiso-witness --loglevel DEBUG 2>>  awiso.log &
echo $! > witness.wiso.pid
kli witness start --name wums --alias wums  -T 5636  -H 5646  --config-dir $CONFIG_DIR  --config-file wums-witness --loglevel DEBUG 2>>  awums.log  &
echo $! > witness.wums.pid
sleep 10
WAN_PREFIX=$(kli status --name wan --alias wan | awk '/Identifier:/ {print $2}')
logEnv WAN_PREFIX $WAN_PREFIX
WARN_PREFIX=$(kli status --name warn --alias warn | awk '/Identifier:/ {print $2}')
logEnv WARN_PREFIX $WARN_PREFIX
WES_PREFIX=$(kli status --name wes --alias wes | awk '/Identifier:/ {print $2}')
logEnv WES_PREFIX $WES_PREFIX
WIL_PREFIX=$(kli status --name wil --alias wil | awk '/Identifier:/ {print $2}')
logEnv WIL_PREFIX $WIL_PREFIX
WISO_PREFIX=$(kli status --name wiso --alias wiso | awk '/Identifier:/ {print $2}')
logEnv WISO_PREFIX $WISO_PREFIX
WUMS_PREFIX=$(kli status --name wums --alias wums | awk '/Identifier:/ {print $2}')
logEnv WUMS_PREFIX $WUMS_PREFIX
echo ""
echo "Witness Wan start with PID $(cat ./witness.wan.pid) and Prefix $WAN_PREFIX"
echo "Witness Warn start with PID $(cat ./witness.warn.pid) and Prefix $WARN_PREFIX"
echo "Witness Wes start with PID $(cat ./witness.wes.pid) and Prefix $WES_PREFIX"
echo "Witness Wil start with PID $(cat ./witness.wil.pid) and Prefix $WIL_PREFIX"
echo "Witness Wiso start with PID $(cat ./witness.wiso.pid) and Prefix $WISO_PREFIX"
echo "Witness Wums start with PID $(cat ./witness.wums.pid) and Prefix $WUMS_PREFIX"
witnessLog "#endregion witness start"
#endregion


#region Controller config
echo "***Updating Controller Configs***"
BOOTSTRAP_CONFDIR="${CONFIG_DIR}/keri/cf"
iurl_new=()
iurl_new+=("http://127.0.0.1:5641/oobi/${WAN_PREFIX}")
iurl_new+=("http://127.0.0.1:5642/oobi/${WARN_PREFIX}")
printf '%s\n' "${iurl_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${BOOTSTRAP_CONFDIR}/bBootstrap.json)" '
    . as $iurl_new | $witconfig | .iurls = $iurl_new'>${BOOTSTRAP_CONFDIR}/bBootstrap.json
echo "config file bBootstrap.json updated with iurls"

iurl_new=()
iurl_new+=("http://127.0.0.1:5643/oobi/${WES_PREFIX}")
iurl_new+=("http://127.0.0.1:5644/oobi/${WIL_PREFIX}")
printf '%s\n' "${iurl_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${BOOTSTRAP_CONFDIR}/cBootstrap.json)" '
    . as $iurl_new | $witconfig | .iurls = $iurl_new' >${BOOTSTRAP_CONFDIR}/cBootstrap.json
echo "config file cBootstrap.json updated with iurls"

iurl_new=()
iurl_new+=("http://127.0.0.1:5645/oobi/${WISO_PREFIX}")
iurl_new+=("http://127.0.0.1:5646/oobi/${WUMS_PREFIX}")
printf '%s\n' "${iurl_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${BOOTSTRAP_CONFDIR}/aBootstrap.json)" '
    . as $iurl_new | $witconfig | .iurls = $iurl_new' > ${BOOTSTRAP_CONFDIR}/aBootstrap.json
echo "config file aBootstrap.json updated with iurls"
#endregion


#region Controller Init
witnessLog "#region Controller Init"
echo "***Initializing Controllers***"
kli init --name bc --salt $SALTBC --nopasscode --config-dir "${CONFIG_DIR}" --config-file bBootstrap.json
kli init --name cc --salt $SALTCC --nopasscode --config-dir "${CONFIG_DIR}" --config-file cBootstrap.json
kli init --name ac --salt $SALTAC --nopasscode --config-dir "${CONFIG_DIR}" --config-file aBootstrap.json
witnessLog "#endregion Controller Init"
#endregion

#region Controller inception config
echo "***Updating Controller Inception Configs***"
wits_new=()
wits_new+=("${WAN_PREFIX}")
wits_new+=("${WARN_PREFIX}")
printf '%s\n' "${wits_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${CONFIG_DIR}/keri/bInception.json)" '
    . as $wits_new | $witconfig | .wits = $wits_new'>${CONFIG_DIR}/keri/bInception.json
echo "updated bInception.json with witness AIDS"

wits_new=()
wits_new+=("${WES_PREFIX}")
wits_new+=("${WIL_PREFIX}")
printf '%s\n' "${wits_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${CONFIG_DIR}/keri/cInception.json)" '
    . as $wits_new | $witconfig | .wits = $wits_new'>${CONFIG_DIR}/keri/cInception.json
echo "updated cInception.json with witness AIDS"

wits_new=()
wits_new+=("${WISO_PREFIX}")
wits_new+=("${WUMS_PREFIX}")
printf '%s\n' "${wits_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${CONFIG_DIR}/keri/aInception.json)" '
    . as $wits_new | $witconfig | .wits = $wits_new'>${CONFIG_DIR}/keri/aInception.json
echo "updated aInception.json with witness AIDS"
#endregion

#region Controller Incept
witnessLog "#region Controller Incept"
echo "***Incepting Controllers***"
output=$(kli incept --name bc --alias bob --file kericonf/keri/bInception.json)
echo $output
bobAID=$(echo $output | grep Prefix | awk '{print $6}')
logEnv bobAID $bobAID
echo "bob Controller incepted with AID: $bobAID"

output=$(kli incept --name cc --alias charlie --file kericonf/keri/cInception.json)
echo $output
charlieAID=$(echo $output | grep Prefix | awk '{print $6}')
logEnv charlieAID $charlieAID
echo "charlie Controller incepted with AID: $charlieAID"

output=$(kli incept --name ac --alias alice --file kericonf/keri/aInception.json)
echo $output
aliceAID=$(echo $output | grep Prefix | awk '{print $6}')
logEnv aliceAID $aliceAID
echo "alice Controller incepted with AID: $aliceAID"
witnessLog "#endregion Controller Incept"
#endregion

#region oobi resolves
echo "***Resolving Oobis***"
witnessLog "#region oobi resolves"
kli oobi resolve --name bc --oobi-alias ccAlias --oobi http://127.0.0.1:5643/oobi/$charlieAID/witness/$WES_PREFIX
kli oobi resolve --name bc --oobi-alias ccAlias2 --oobi http://127.0.0.1:5644/oobi/$charlieAID/witness/$WIL_PREFIX
kli oobi resolve --name bc --oobi-alias acAlias --oobi http://127.0.0.1:5645/oobi/$aliceAID/witness/$WISO_PREFIX
kli oobi resolve --name bc --oobi-alias acAlias2 --oobi http://127.0.0.1:5646/oobi/$aliceAID/witness/$WUMS_PREFIX
echo "Resolved bc oobis"

kli oobi resolve --name cc --oobi-alias bcAlias --oobi http://127.0.0.1:5641/oobi/$bobAID/witness/$WAN_PREFIX
kli oobi resolve --name cc --oobi-alias bcAlias2 --oobi http://127.0.0.1:5642/oobi/$bobAID/witness/$WARN_PREFIX
kli oobi resolve --name cc --oobi-alias acAlias --oobi http://127.0.0.1:5645/oobi/$aliceAID/witness/$WISO_PREFIX
kli oobi resolve --name cc --oobi-alias acAlias2 --oobi http://127.0.0.1:5646/oobi/$aliceAID/witness/$WUMS_PREFIX
echo "Resolved cc oobis"

kli oobi resolve --name ac --oobi-alias bcAlias --oobi http://127.0.0.1:5641/oobi/$bobAID/witness/$WAN_PREFIX
kli oobi resolve --name ac --oobi-alias bcAlias2 --oobi http://127.0.0.1:5642/oobi/$bobAID/witness/$WARN_PREFIX
kli oobi resolve --name ac --oobi-alias ccAlias --oobi http://127.0.0.1:5643/oobi/$charlieAID/witness/$WES_PREFIX
kli oobi resolve --name ac --oobi-alias ccAlias2 --oobi http://127.0.0.1:5644/oobi/$charlieAID/witness/$WIL_PREFIX
echo "Resolved ac oobis"
witnessLog "#endregion oobi resolves"
#endregion


#region Registries
echo "***Incepting Registries***"
witnessLog "#region Registries"
output=$(kli vc registry incept --name bc --alias bob --registry-name bcR)
echo $output
bRegistryAID=$(echo $output | grep Registry | awk -F '[()]' '{print $2}')
logEnv bRegistryAID $bRegistryAID
output=$(kli vc registry incept --name cc --alias charlie --registry-name ccR)
echo $output
cRegistryAID=$(echo $output | grep Registry | awk -F '[()]' '{print $2}')
logEnv cRegistryAID $cRegistryAID
output=$(kli vc registry incept --name ac --alias alice --registry-name acR)
echo $output
aRegistryAID=$(echo $output | grep Registry | awk -F '[()]' '{print $2}')
logEnv aRegistryAID $aRegistryAID
witnessLog "#endregion Registries"
#endregion 

#region Facility acdc
echo "***Facility ACDC***"
witnessLog "#region facility acdc"
facilityCredSAID=$(kli vc create --name cc --alias charlie --registry-name ccR --schema EKSRe0Z5YDOJxdITHoQVEhfYi5cjIYFVYoyQeiIrz-b2 --recipient bcAlias --data @credential_data/identity.json --rules @credential_data/rulesFacility.json)
facilityCredSAID=$(echo "$facilityCredSAID" | grep has | awk '{print $1}')
echo "FacilityCredSAID: $facilityCredSAID"

echo "Granting / sending credential using ipex"
kli ipex grant --name cc --alias charlie --said $facilityCredSAID --recipient bc
echo "Credential granted"
echo "Checking holder for grant messages..."
GRANT=$(kli ipex list --name bc --alias bob --poll --said)
echo "Admitting credential from grant ${GRANT}"
kli ipex admit --name bc --alias bob --said "${GRANT}"
facilityCredID=$(kli vc list --name bc --alias bob |  grep Credential | awk '{print $3}'  | tail -n 1)
echo "Facility Credential ID: ${facilityCredID}"
logEnv facilityCredID $facilityCredID
witnessLog "#endregion facility acdc"
#endregion

#region identity/treasure hunting acdc
echo "***identity ACDC***"
witnessLog "#region identity acdc"
identityCredSAID=$(kli vc create --name cc --alias charlie --registry-name ccR --schema EIxAox3KEhiQ_yCwXWeriQ3ruPWbgK94NDDkHAZCuP9l --recipient acAlias --data @credential_data/identity.json --rules @credential_data/rulesIdentity.json)
identityCredSAID=$(echo "$identityCredSAID" | grep has | awk '{print $1}')
echo "identityCredSAID: $identityCredSAID"
echo "Granting / sending credential using ipex"
kli ipex grant --name cc --alias charlie --said $identityCredSAID --recipient ac
echo "Credential granted"
echo "Checking holder for grant messages..."
GRANT=$(kli ipex list --name ac --alias alice --poll --said)
echo "Admitting credential from grant ${GRANT}"
kli ipex admit --name ac --alias alice --said "${GRANT}"
identityCredID=$(kli vc list --name ac --alias alice  |  grep Credential | awk '{print $3}' | tail -n 1)
logEnv identityCredID $identityCredID
echo "identity Credential ID: ${identityCredID}"
witnessLog "#endregion identity acdc"
#endregion



#region PAC ACDC
echo "***PAC ACDC***"
witnessLog "#region PAC ACDC"
echo "Creating Edge for PAC"
echo "\"${identityCredID}\"" | jq -f "credential_data/identity.jq" > credential_data/identity_edge.json
kli saidify --file credential_data/identity_edge.json
cat credential_data/identity_edge.json
echo "Creating PAC Credential"
PACAID=$(kli vc create --name ac --alias alice --registry-name acR --schema ECJOwrjiD-g5ITcEVubwG_rm_3QKPGKWUfljTbqpBgKI --recipient ${aliceAID} --data @credential_data/pac.json --edge @credential_data/identity_edge.json --rules @credential_data/rulesPac.json)
echo $PACAID
PACAID=$(echo "$PACAID" | grep has | awk '{print $1}')
logEnv PACAID $PACAID
echo "PAC Credential AID: $PACAID created and issued"


kli ipex grant --name ac --alias alice --said ${PACAID} --recipient bc
GRANT=$(kli ipex list --name bc --alias bob --poll --said| tail -n1)
kli ipex list --name bc -V

echo "###Outside Challenge validation happening here###"

kli ipex admit --name bc --alias bob --said "${GRANT}"
witnessLog "#endregion PAC ACDC"
#endregion 


#region AttestationACDC
echo "***Attestation ACDC***"
witnessLog "#region Attestation ACDC"
echo "Creating Edges for Attestation"

echo "$(jq --null-input --arg PACCredID "$PACAID" --arg facilityCredID "$facilityCredID" -f credential_data/attestation-edges.jq)" > credential_data/attestation_edges.json
kli saidify --file credential_data/attestation_edges.json
cat credential_data/attestation_edges.json
echo ""

witnessLog "region A ACDC start" 
echo "Creating attestation Credential"
#attestationAID=$(kli vc create --name bc --alias bob --registry-name bcR --schema ENpwyXio-RdNBazqrHSP1Ctl41qf_NPVnmj8eYP7IwTK --recipient ccAlias --data @credential_data/attestation.json --edge @credential_data/attestation_edges.json --rules @credential_data/rulesAttestation.json)
AAID=$(kli vc create --name bc --alias bob --registry-name bcR --schema ENpwyXio-RdNBazqrHSP1Ctl41qf_NPVnmj8eYP7IwTK --recipient ccAlias --data @credential_data/attestation.json --edge @credential_data/attestation_edges.json --rules @credential_data/rulesAttestation.json)
echo $AAID
AAID=$(echo "$AAID" | grep has | awk '{print $1}')
logEnv AAID $AAID
echo "Attestation Credential AID: $AAID created and issued"


kli ipex grant --name bc --alias bob --said ${AAID} --recipient cc
GRANT=$(kli ipex list --name cc --alias charlie --poll --said| tail -n1)
kli ipex list --name cc -V


echo "###Outside Challenge validation happening here###"

kli ipex admit --name cc --alias charlie --said "${GRANT}"
witnessLog "#endregion A ACDC"
#endregion 