#!/bin/bash
source .env

function notify() {
  echo "Send notify $*"
  curl -s --get "https://api.telegram.org/bot$TG_API_KEY/sendMessage" \
    --data-urlencode "chat_id=$TG_CHAT_ID" \
    --data-urlencode "text=$*"
}

function check_node_status() {
  STATUS=$(curl -s http://$NODE_RPC/status)

  NOW=$(echo "$STATUS" | jq -c ".version")
  LAST=$(cat state.status)

  if [ "$LAST" != "$NOW" ]; then
    if [ -z "$NOW" ]; then
      notify "đ¨ Node status changed: OFFLINE"
    else
      notify "â Node status changed: ONLINE"
    fi
    echo "$NOW" > state.status
  fi

  NOW=$(echo "$STATUS" | jq -c ".sync_info.syncing")
  LAST=$(cat state.syncing)

  if [ "$NOW" != "$LAST" ]; then
    notify "đĻ Node syncing changed: $NOW"
    echo "$NOW" > state.syncing
  fi
}

function check_validator_status() {
  VALIDATORS=$(curl -s -d '{"jsonrpc": "2.0", "method": "validators", "id": "dontcare", "params": [null]}' -H 'Content-Type: application/json' $NODE_RPC)
  CURRENT_VALIDATOR=$(echo "$VALIDATORS" | jq -c ".result.current_validators[] | select(.account_id | contains (\"$POOL_ID\"))")
  NEXT_VALIDATORS=$(echo "$VALIDATORS" | jq -c ".result.next_validators[] | select(.account_id | contains (\"$POOL_ID\"))")
  CURRENT_PROPOSALS=$(echo "$VALIDATORS" | jq -c ".result.current_proposals[] | select(.account_id | contains (\"$POOL_ID\"))")
  KICK_REASON=$(echo "$VALIDATORS" | jq -c ".result.prev_epoch_kickout[] | select(.account_id | contains (\"$POOL_ID\"))" | jq .reason)

  LAST_POS=$(cat state.position)
  NOW_POS=""

  [ -n "$CURRENT_VALIDATOR" ] && [ -z "$NOW_POS" ] && NOW_POS="â Validator"
  [ -n "$NEXT_VALIDATORS" ] && [ -z "$NOW_POS" ] && NOW_POS="đ Joining"
  [ -n "$CURRENT_PROPOSALS" ] && [ -z "$NOW_POS" ] && NOW_POS="đ Proposal"
  [ -n "$KICK_REASON" ] && NOW_POS="đ¨ Kicked: $KICK_REASON"

  if [ "$LAST_POS" != "$NOW_POS" ]; then
    notify "âšī¸ Position changed: $NOW_POS"
    echo "$NOW_POS" > state.position
  fi

  LAST_STAKE=$(cat state.stake)
  NOW_STAKE=$(echo "${CURRENT_VALIDATOR:-${NEXT_VALIDATORS:-${CURRENT_PROPOSALS}}}" | jq -c ".stake")

  if [ "$LAST_STAKE" != "$NOW_STAKE" ]; then
    notify "đ° Stake changed: $NOW_STAKE"
    echo "$NOW_STAKE" > state.stake
  fi
}

check_node_status
check_validator_status
