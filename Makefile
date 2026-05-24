# Makefile for RISC-V Doc Template
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Description:
#
# This Makefile is designed to automate the process of building and packaging
# the Doc Template for RISC-V Extensions.

DOCS := \
	spec-sample.adoc

# Spec short name used in ARC-compliant PDF filenames.
# Override in derived repos: e.g. SPEC_SHORT := Zifoo
SPEC_SHORT ?= $(basename $(firstword $(DOCS)))

DATE ?= $(shell date +%Y-%m-%d)
DATE_STAMP := $(subst -,,$(DATE))
VERSION ?= $(shell ./scripts/release-info.sh version)
VERSION_NUM := $(patsubst v%,%,$(VERSION))
PHASE ?= $(shell ./scripts/release-info.sh phase "$(VERSION)")
PHASE_DISPLAY ?= $(shell ./scripts/release-info.sh display "$(VERSION)")
PHASE_NOTICE ?= $(shell ./scripts/release-info.sh notice "$(VERSION)")
REVMARK ?= $(shell ./scripts/release-info.sh revremark "$(VERSION)")
MILESTONE_ID ?= $(PHASE)
DOCKER_IMG := docker.io/riscvintl/riscv-docs-base-container-image:latest
DOCKER_BIN ?= docker
ifneq ($(SKIP_DOCKER),true)
	DOCKER_IS_PODMAN = \
		$(shell ! ${DOCKER_BIN} -v 2>&1 | grep podman >/dev/null ; echo $$?)
	ifeq "$(DOCKER_IS_PODMAN)" "1"
		DOCKER_VOL_SUFFIX = :z
	endif

	DOCKER_CMD := \
		${DOCKER_BIN} run --rm \
			-v ${PWD}:/build${DOCKER_VOL_SUFFIX} \
			-w /build \
			${DOCKER_IMG} \
			/bin/sh -c
	DOCKER_QUOTE := "
endif

SRC_DIR := src
BUILD_DIR := build

DOCS_PDF := $(DOCS:%.adoc=%.pdf)
DOCS_HTML := $(DOCS:%.adoc=%.html)

XTRA_ADOC_OPTS :=
ASCIIDOCTOR_PDF := asciidoctor-pdf
ASCIIDOCTOR_HTML := asciidoctor
OPTIONS := --trace \
           -a compress \
           -a mathematical-format=svg \
           -a revnumber=${VERSION} \
           -a revremark='${REVMARK}' \
           -a revdate=${DATE} \
           -a phase='${PHASE}' \
           -a phase_display='${PHASE_DISPLAY}' \
           -a phase_notice='${PHASE_NOTICE}' \
           -a milestone_id='${MILESTONE_ID}' \
           -a spec_short='${SPEC_SHORT}' \
           -a pdf-fontsdir=docs-resources/fonts \
           -a pdf-theme=docs-resources/themes/riscv-pdf.yml \
           $(XTRA_ADOC_OPTS) \
		   -D build \
           --failure-level=ERROR
REQUIRES := --require=asciidoctor-bibtex \
            --require=asciidoctor-diagram \
			--require=asciidoctor-lists \
            --require=asciidoctor-mathematical

.PHONY: all build clean build-container build-no-container build-docs arc-rename

all: build

# After AsciiDoctor produces build/<basename>.pdf, rename each PDF to the
# ARC-compliant form <basename>-v<version>-<YYYYMMDD>.pdf so every build
# (local or CI) emits a uniquely identifiable artifact.
build-docs: $(DOCS_PDF) $(DOCS_HTML) arc-rename

arc-rename: $(DOCS_PDF)
	@for pdf in $(DOCS_PDF); do \
		base=$$(basename $$pdf .pdf); \
		dest="$$base-v$(VERSION_NUM)-$(DATE_STAMP).pdf"; \
		if [ -f build/$$pdf ]; then \
			mv build/$$pdf build/$$dest; \
			echo "ARC submission PDF: build/$$dest"; \
		fi; \
	done

vpath %.adoc $(SRC_DIR)

%.pdf: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

%.html: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

build:
	@echo "Checking if Docker is available..."
	@if command -v ${DOCKER_BIN} >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi

build-container:
	@echo "Starting build inside Docker container..."
	$(MAKE) build-docs
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(MAKE) SKIP_DOCKER=true build-docs
	@echo "Build completed successfully."

# Update docker image to latest
docker-pull-latest:
	${DOCKER_BIN} pull ${DOCKER_IMG}

clean:
	@echo "Cleaning up generated files..."
	rm -rf $(BUILD_DIR)
	@echo "Cleanup completed."
