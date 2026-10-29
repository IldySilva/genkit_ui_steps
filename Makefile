.PHONY: help step1 step2 step3 step4 step5 step6 step7 step8 step9 step10 step11 main run analyze status

.DEFAULT_GOAL := help

# Terminal color codes
CYAN    := \033[36m
GREEN   := \033[32m
YELLOW  := \033[33m
MAGENTA := \033[35m
BOLD    := \033[1m
RESET   := \033[0m

help:
	@echo ""
	@echo "$(BOLD)$(CYAN)=========================================================$(RESET)"
	@echo "$(BOLD)$(CYAN)       FLUTTER GOES AI - LIVE DEMO CONTROLLER            $(RESET)"
	@echo "$(BOLD)$(CYAN)=========================================================$(RESET)"
	@echo ""
	@echo "$(BOLD)$(YELLOW)Switch Branches (Step-by-Step Presentation):$(RESET)"
	@echo "  $(GREEN)make step1$(RESET)    -> Step 1: Basic AI (Call & Response)"
	@echo "  $(GREEN)make step2$(RESET)    -> Step 2: Streaming Tokens into UI"
	@echo "  $(GREEN)make step3$(RESET)    -> Step 3: Structured Output (schemantic)"
	@echo "  $(GREEN)make step4$(RESET)    -> Step 4: Function Calling [THE WOW MOMENT]"
	@echo "  $(GREEN)make step5$(RESET)    -> Step 5: Local On-Device AI (llamadart)"
	@echo "  $(GREEN)make step6$(RESET)    -> Step 6: Stateful Agents & Interrupts"
	@echo "  $(GREEN)make step7$(RESET)    -> Step 7: Final Polished Remote Control"
	@echo "  $(GREEN)make step8$(RESET)    -> Step 8: Vector Embeddings & Similarity"
	@echo "  $(GREEN)make step9$(RESET)    -> Step 9: Middlewares, Retries & Cancel"
	@echo "  $(GREEN)make step10$(RESET)   -> Step 10: Multi-Agent & Snapshot Rewind"
	@echo "  $(GREEN)make step11$(RESET)   -> Step 11: A2UI Generative UI (Dynamic Surfaces)"
	@echo "  $(GREEN)make main$(RESET)     -> Return to main branch"
	@echo ""
	@echo "$(BOLD)$(YELLOW)Direct Execution Commands (macOS):$(RESET)"
	@echo "  $(GREEN)make run$(RESET)       -> Run current branch (flutter run -d macos)"
	@echo "  $(GREEN)make analyze$(RESET)   -> Verify code health (flutter analyze)"
	@echo "  $(GREEN)make status$(RESET)    -> Show current branch and git status"
	@echo ""

step1:
	@echo "$(CYAN)➡️  Switching to Step 1: Basic AI...$(RESET)"
	@git checkout step/1-basic

step2:
	@echo "$(CYAN)➡️  Switching to Step 2: Streaming...$(RESET)"
	@git checkout step/2-streaming

step3:
	@echo "$(CYAN)➡️  Switching to Step 3: Structured Output...$(RESET)"
	@git checkout step/3-structured

step4:
	@echo "$(CYAN)➡️  Switching to Step 4: Function Calling (The Wow Moment)...$(RESET)"
	@git checkout step/4-tools

step5:
	@echo "$(CYAN)➡️  Switching to Step 5: Local On-Device AI...$(RESET)"
	@git checkout step/5-local

step6:
	@echo "$(CYAN)➡️  Switching to Step 6: Stateful Agents & Human Approval...$(RESET)"
	@git checkout step/6-agents

step7:
	@echo "$(CYAN)➡️  Switching to Step 7: Final Polished Demo...$(RESET)"
	@git checkout step/7-final

step8:
	@echo "$(CYAN)➡️  Switching to Step 8: Vector Embeddings & Similarity...$(RESET)"
	@git checkout step/8-embeddings

step9:
	@echo "$(CYAN)➡️  Switching to Step 9: Middlewares & Stream Cancel...$(RESET)"
	@git checkout step/9-middlewares

step10:
	@echo "$(CYAN)➡️  Switching to Step 10: Multi-Agent & Snapshots...$(RESET)"
	@git checkout step/10-multi-agent

step11:
	@echo "$(CYAN)➡️  Switching to Step 11: A2UI Generative UI...$(RESET)"
	@git checkout step/11-a2ui

main:
	@echo "$(CYAN)➡️  Switching to main branch...$(RESET)"
	@git checkout main

run:
	flutter run -d macos

analyze:
	flutter analyze

status:
	@git status -s -b
