.PHONY: task1-cluster-up task1-build task1-baseline task1-check task1-clean

task1-cluster-up:
	./task1/scripts/cluster-up.sh

task1-build:
	./task1/scripts/build.sh

task1-baseline:
	./task1/scripts/deploy-insecure.sh

task1-check:
	./task1/scripts/check-functional.sh

task1-clean:
	./task1/scripts/cleanup.sh
