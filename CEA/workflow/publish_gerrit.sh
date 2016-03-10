#!/bin/bash -x

case "$1" in
  "cmake")
    VERF="-1"
    MESSAGE="Build failed:"$'\n'"$(cd build; cmake ../src/ -DBUILD_CONFIG=everything -DLUSTRE_PREFIX=/opt/lustre/usr -DUSE_9P_RDMA=ON -DUSE_FSAL_HPSS=ON 2>&1 | grep -v fleury)" #-DUSE_FSAL_HPSS=ON
    ;;
  "build")
    VERF="-1"
    MESSAGE="Build failed:"$'\n'"$(cd build; make 2>&1 >/dev/null)"
    ;;
  *)
    if [[ -e "/tmp/test_report.xml" ]]; then
      TEST_TOTAL=$(grep -c '<testcase' /tmp/test_report.xml) || true
      TEST_SKIPPED=$(grep -c '<skipped' /tmp/test_report.xml) || true
      TEST_TOTAL=$((TEST_TOTAL-TEST_SKIPPED))
      TEST_FAILED=$(grep -c '<failure' /tmp/test_report.xml) || true
      if [[ "$TEST_FAILED" == "0" ]]; then
        VERF="1"
        MESSAGE="Build OK - tests OK ($TEST_TOTAL)"
      else
        FAILURES=$(grep -B1 '<failure' /tmp/test_report.xml | sed -ne 's/.*name="\([^"]*\)".*/\1/p' || true)
        VERF="0"
        MESSAGE="Build OK - tests failures ($TEST_FAILED/$TEST_TOTAL failed):"$'\n'"$FAILURES"
      fi
    else
      VERF="-1"
      MESSAGE="Build OK - tests couldn't run"
    fi
esac

NOTIFY="ALL"
if [[ "$VERF" != "-1" ]]; then
	NOTIFY="NONE"
fi

if [[ "$GERRIT_PUBLISH" == "true" ]]; then
  echo '{"message": "'"$MESSAGE"'", "labels": { "Verified": '"$VERF"' }, "notify": '"$NOTIFY"' }' | \
    ssh -i/root/.ssh/id_rsa_ganesha-triggers -p 29418 cea-gerrithub-hpc@review.gerrithub.io \
        "gerrit review --json --project ffilz/nfs-ganesha $REVISION"
else
  echo "echo '{\"message\": \"$MESSAGE\", \"labels\": { \"Verified\": \"$VERF\" }, \"notify\": \"$NOTIFY\" }' | \\
  ssh -i/root/.ssh/id_rsa_ganesha-triggers -p 29418 cea-gerrithub-hpc@review.gerrithub.io \\
    \"gerrit review --json --project ffilz/nfs-ganesha $REVISION\""
fi
