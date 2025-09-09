#!/usr/bin/env bash
set -euo pipefail

# ===== Settings =====
DRY_RUN="${DRY_RUN:-true}"                   # set to "false" to actually delete
PROFILE_ARG="${PROFILE:+--profile $PROFILE}" # e.g. export PROFILE=myprofile
REGIONS="${REGIONS:-}"

say() { printf "\n%s\n" "$*" >&2; }
doit() {
  local cmd="$*"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $cmd"
  else
    eval "$cmd"
  fi
}

# Get regions
if [[ -z "$REGIONS" ]]; then
  say "Discovering enabled regions..."
  mapfile -t REGION_LIST < <(aws ec2 describe-regions $PROFILE_ARG --query 'Regions[].RegionName' --output text | tr '\t' '\n' | sort)
else
  read -r -a REGION_LIST <<<"$REGIONS"
fi

say "Regions to process: ${REGION_LIST[*]:-<none>}"
[[ ${#REGION_LIST[@]} -eq 0 ]] && { say "No regions found. Exiting."; exit 0; }

# Helper to json-safe quote
jq_quote() { python3 - <<'PY'
import json,sys
print(json.dumps(sys.stdin.read().strip()))
PY
}

# ===== Per-region cleanup functions =====
cleanup_ec2_compute() {
  local region="$1"
  say "[$region] EC2 Instances"
  # Terminate ALL instances
  mapfile -t INSTANCES < <(aws ec2 describe-instances $PROFILE_ARG --region "$region" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#INSTANCES[@]} -gt 0 && -n "${INSTANCES[0]:-}" ]]; then
    doit aws ec2 terminate-instances $PROFILE_ARG --region "$region" --instance-ids "${INSTANCES[@]}"
  else
    echo "None"
  fi
}

cleanup_eips() {
  local region="$1"
  say "[$region] Elastic IPs (release any, especially unattached)"
  mapfile -t ALLOCS < <(aws ec2 describe-addresses $PROFILE_ARG --region "$region" \
    --query 'Addresses[].AllocationId' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#ALLOCS[@]} -gt 0 && -n "${ALLOCS[0]:-}" ]]; then
    for a in "${ALLOCS[@]}"; do
      doit aws ec2 release-address $PROFILE_ARG --region "$region" --allocation-id "$a"
    done
  else
    echo "None"
  fi
}

cleanup_nat_gateways() {
  local region="$1"
  say "[$region] NAT Gateways"
  mapfile -t NATS < <(aws ec2 describe-nat-gateways $PROFILE_ARG --region "$region" \
    --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#NATS[@]} -gt 0 && -n "${NATS[0]:-}" ]]; then
    for ngw in "${NATS[@]}"; do
      doit aws ec2 delete-nat-gateway $PROFILE_ARG --region "$region" --nat-gateway-id "$ngw"
    done
  else
    echo "None"
  fi
}

cleanup_elb_classic() {
  local region="$1"
  say "[$region] Classic ELB"
  mapfile -t ELBS < <(aws elb describe-load-balancers $PROFILE_ARG --region "$region" \
    --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#ELBS[@]} -gt 0 && -n "${ELBS[0]:-}" ]]; then
    for lb in "${ELBS[@]}"; do
      doit aws elb delete-load-balancer $PROFILE_ARG --region "$region" --load-balancer-name "$lb"
    done
  else
    echo "None"
  fi
}

cleanup_elb_v2() {
  local region="$1"
  say "[$region] ALB/NLB (ELBv2)"
  mapfile -t ELBS < <(aws elbv2 describe-load-balancers $PROFILE_ARG --region "$region" \
    --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#ELBS[@]} -gt 0 && -n "${ELBS[0]:-}" ]]; then
    for arn in "${ELBS[@]}"; do
      doit aws elbv2 delete-load-balancer $PROFILE_ARG --region "$region" --load-balancer-arn "$arn"
    done
  else
    echo "None"
  fi
}

cleanup_ebs() {
  local region="$1"
  say "[$region] EBS Volumes"
  mapfile -t VOLS < <(aws ec2 describe-volumes $PROFILE_ARG --region "$region" \
    --query 'Volumes[].VolumeId' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#VOLS[@]} -gt 0 && -n "${VOLS[0]:-}" ]]; then
    for v in "${VOLS[@]}"; do
      doit aws ec2 delete-volume $PROFILE_ARG --region "$region" --volume-id "$v"
    done
  else
    echo "None"
  fi

  say "[$region] EBS Snapshots (owned by me)"
  mapfile -t SNAPS < <(aws ec2 describe-snapshots $PROFILE_ARG --region "$region" --owner-ids self \
    --query 'Snapshots[].SnapshotId' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#SNAPS[@]} -gt 0 && -n "${SNAPS[0]:-}" ]]; then
    for s in "${SNAPS[@]}"; do
      doit aws ec2 delete-snapshot $PROFILE_ARG --region "$region" --snapshot-id "$s"
    done
  else
    echo "None"
  fi

  say "[$region] Custom AMIs (deregister + snapshots)"
  mapfile -t AMIS < <(aws ec2 describe-images $PROFILE_ARG --region "$region" --owners self \
    --query 'Images[].ImageId' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#AMIS[@]} -gt 0 && -n "${AMIS[0]:-}" ]]; then
    for ami in "${AMIS[@]}"; do
      doit aws ec2 deregister-image $PROFILE_ARG --region "$region" --image-id "$ami"
    done
  else
    echo "None"
  fi
}

cleanup_lambda_logs() {
  local region="$1"
  say "[$region] Lambda Functions"
  mapfile -t FUNCS < <(aws lambda list-functions $PROFILE_ARG --region "$region" \
    --query 'Functions[].FunctionName' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#FUNCS[@]} -gt 0 && -n "${FUNCS[0]:-}" ]]; then
    for fn in "${FUNCS[@]}"; do
      doit aws lambda delete-function $PROFILE_ARG --region "$region" --function-name "$fn"
    done
  else
    echo "None"
  fi

  say "[$region] CloudWatch Log Groups"
  mapfile -t LG < <(aws logs describe-log-groups $PROFILE_ARG --region "$region" \
    --query 'logGroups[].logGroupName' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#LG[@]} -gt 0 && -n "${LG[0]:-}" ]]; then
    for g in "${LG[@]}"; do
      doit aws logs delete-log-group $PROFILE_ARG --region "$region" --log-group-name "$g"
    done
  else
    echo "None"
  fi

  say "[$region] CloudWatch Alarms"
  mapfile -t ALARMS < <(aws cloudwatch describe-alarms $PROFILE_ARG --region "$region" \
    --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null | tr '\t' '\n' || true)
  if [[ ${#ALARMS[@]} -gt 0 && -n "${ALARMS[0]:-}" ]]; then
    doit aws cloudwatch delete-alarms $PROFILE_ARG --region "$region" --alarm-names "${ALARMS[@]}"
  else
    echo "None"
  fi
}

cleanup_glue() {
  local region="$1"
  say "[$region] Glue Crawlers"
  mapfile -t CRAWLERS < <(aws glue list-crawlers $PROFILE_ARG --region "$region" \
    --query 'CrawlerNames[]' --output text 2>/dev/null | tr '\t' '\n' || true)
  for c in "${CRAWLERS[@]:-}"; do
    [[ -n "$c" ]] && doit aws glue delete-crawler $PROFILE_ARG --region "$region" --name "$c"
  done

  say "[$region] Glue Databases"
  mapfile -t DBs < <(aws glue get-databases $PROFILE_ARG --region "$region" \
    --query 'DatabaseList[].Name' --output text 2>/dev/null | tr '\t' '\n' || true)
  for d in "${DBs[@]:-}"; do
    [[ -n "$d" ]] && doit aws glue delete-database $PROFILE_ARG --region "$region" --name "$d"
  done
}

cleanup_rds() {
  local region="$1"
  say "[$region] RDS Instances"
  mapfile -t DBS < <(aws rds describe-db-instances $PROFILE_ARG --region "$region" \
    --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null | tr '\t' '\n' || true)
  for db in "${DBS[@]:-}"; do
    [[ -n "$db" ]] && doit aws rds delete-db-instance $PROFILE_ARG --region "$region" \
      --db-instance-identifier "$db" --skip-final-snapshot
  done

  say "[$region] RDS Clusters (Aurora)"
  mapfile -t CLUS < <(aws rds describe-db-clusters $PROFILE_ARG --region "$region" \
    --query 'DBClusters[].DBClusterIdentifier' --output text 2>/dev/null | tr '\t' '\n' || true)
  for c in "${CLUS[@]:-}"; do
    [[ -n "$c" ]] && doit aws rds delete-db-cluster $PROFILE_ARG --region "$region" \
      --db-cluster-identifier "$c" --skip-final-snapshot
  done

  say "[$region] RDS Snapshots"
  mapfile -t SS < <(aws rds describe-db-snapshots $PROFILE_ARG --region "$region" \
    --query 'DBSnapshots[].DBSnapshotIdentifier' --output text 2>/dev/null | tr '\t' '\n' || true)
  for s in "${SS[@]:-}"; do
    [[ -n "$s" ]] && doit aws rds delete-db-snapshot $PROFILE_ARG --region "$region" \
      --db-snapshot-identifier "$s"
  done
}

cleanup_dynamodb() {
  local region="$1"
  say "[$region] DynamoDB Tables"
  mapfile -t TABLES < <(aws dynamodb list-tables $PROFILE_ARG --region "$region" \
    --query 'TableNames[]' --output text 2>/dev/null | tr '\t' '\n' || true)
  for t in "${TABLES[@]:-}"; do
    [[ -n "$t" ]] && doit aws dynamodb delete-table $PROFILE_ARG --region "$region" --table-name "$t"
  done
}

cleanup_s3_all_regions_hint() {
  say "[global] S3 Buckets (empties + deletes). This part is GLOBAL (no region filter)."
  mapfile -t BUCKETS < <(aws s3api list-buckets $PROFILE_ARG --query 'Buckets[].Name' --output text | tr '\t' '\n' || true)
  if [[ ${#BUCKETS[@]} -eq 0 || -z "${BUCKETS[0]:-}" ]]; then
    echo "No buckets found."
    return
  fi

  for b in "${BUCKETS[@]}"; do
    say "Processing bucket: s3://$b"
    # Try to delete with force; for versioned buckets we’ll do a deeper delete
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY-RUN] aws s3 rb s3://$b --force"
    else
      if ! aws s3 rb s3://"$b" --force $PROFILE_ARG 2>/dev/null; then
        # Handle versioned buckets thoroughly
        say "Bucket likely versioned; deleting all object versions and delete markers..."
        # Delete object versions
        TOK=""
        while :; do
          RESP=$(aws s3api list-object-versions $PROFILE_ARG --bucket "$b" ${TOK:+--starting-token "$TOK"} --output json || true)
          IDS=$(echo "$RESP" | jq -r '.Versions[]? | [.Key, .VersionId] | @tsv')
          MARKS=$(echo "$RESP" | jq -r '.DeleteMarkers[]? | [.Key, .VersionId] | @tsv')
          if [[ -z "$IDS" && -z "$MARKS" ]]; then break; fi
          {
            echo '{ "Objects": ['
            (echo "$IDS"; echo "$MARKS") | awk 'NF{printf("{\"Key\":\"%s\",\"VersionId\":\"%s\"},\n",$1,$2)}' | sed '$ s/,$//'
            echo '], "Quiet": true }'
          } > /tmp/del.json
          aws s3api delete-objects $PROFILE_ARG --bucket "$b" --delete file:///tmp/del.json >/dev/null || true
          NT=$(echo "$RESP" | jq -r '.NextToken // empty')
          [[ -z "$NT" ]] && break || TOK="$NT"
        done
        # Attempt bucket delete again
        aws s3 rb s3://"$b" $PROFILE_ARG --force || true
      fi
    fi
  done
}

cleanup_glue_iam_note() {
  say "[note] IAM roles/policies generally do not incur cost by themselves; not deleting IAM here."
}

cleanup_route53() {
  say "[global] Route 53 Hosted Zones"
  mapfile -t ZONES < <(aws route53 list-hosted-zones $PROFILE_ARG --query 'HostedZones[].Id' --output text | tr '\t' '\n' | sed 's#/hostedzone/##' || true)
  for z in "${ZONES[@]:-}"; do
    [[ -z "$z" ]] && continue
    say "Hosted Zone: $z (deleting non-default records, then the zone)"
    # List all record sets
    TMP=$(mktemp)
    aws route53 list-resource-record-sets $PROFILE_ARG --hosted-zone-id "$z" > "$TMP"
    # Delete everything except SOA and NS at the zone apex
    COUNT=$(jq '.ResourceRecordSets | length' "$TMP")
    for i in $(seq 0 $((COUNT-1))); do
      NAME=$(jq -r ".ResourceRecordSets[$i].Name" "$TMP")
      TYPE=$(jq -r ".ResourceRecordSets[$i].Type" "$TMP")
      if [[ "$TYPE" == "SOA" || "$TYPE" == "NS" ]]; then
        # keep apex SOA/NS only
        continue
      fi
      CHANGE=$(jq -n --argjson rr "$(jq ".ResourceRecordSets[$i]" "$TMP")" '{Changes:[{Action:"DELETE", ResourceRecordSet:$rr}]}' )
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] aws route53 change-resource-record-sets --hosted-zone-id $z --change-batch '...DELETE $TYPE $NAME...'"
      else
        aws route53 change-resource-record-sets $PROFILE_ARG --hosted-zone-id "$z" --change-batch "$CHANGE" >/dev/null || true
      fi
    done
    rm -f "$TMP"

    # Finally, delete the hosted zone
    doit aws route53 delete-hosted-zone $PROFILE_ARG --id "$z"
  done
}

# ===== Execute per region =====
for R in "${REGION_LIST[@]}"; do
  say "================ REGION: $R ================"
  cleanup_ec2_compute "$R"
  cleanup_elb_v2 "$R"
  cleanup_elb_classic "$R"
  cleanup_nat_gateways "$R"
  cleanup_eips "$R"
  cleanup_ebs "$R"
  cleanup_lambda_logs "$R"
  cleanup_glue "$R"
  cleanup_rds "$R"
  cleanup_dynamodb "$R"
done

# Global-ish services (no region)
cleanup_s3_all_regions_hint
cleanup_route53
cleanup_glue_iam_note

say "Done. DRY_RUN=$DRY_RUN"
