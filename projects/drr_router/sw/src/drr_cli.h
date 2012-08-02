/*
 * $Id$
 * Author: Drew Mazurek
 *
 * Command line service layer for DRR actions.
 *
 * Copyright (c) 2008, Stanford University
 */

#ifndef _I_CLI_DRR_H
#define _I_CLI_DRR_H

#include "or_data_types.h"

void drr_register_cli_commands(node **cli_commands);

void drr_cli_show(router_state *router, cli_request *req);

void drr_cli_set_slow(router_state *router, cli_request *req);

void drr_cli_set_weight(router_state *router, cli_request *req);

void drr_cli_set_quantum(router_state *router, cli_request *req);

void drr_cli_set_policy_tos(router_state *router, cli_request *req);
void drr_cli_set_policy_port(router_state *router, cli_request *req);

void drr_cli_set_tos(router_state *router, cli_request *req);

void drr_cli_reset_stats(router_state *router, cli_request *req);

void drr_cli_help(router_state *router, cli_request *req);
void drr_cli_help_reset(router_state *router, cli_request *req);
void drr_cli_help_set(router_state *router, cli_request *req);
void drr_cli_help_set_slow(router_state *router, cli_request *req);
void drr_cli_help_set_weight(router_state *router, cli_request *req);
void drr_cli_help_set_quantum(router_state *router, cli_request *req);
void drr_cli_help_set_policy(router_state *router, cli_request *req);
void drr_cli_help_set_tos(router_state *router, cli_request *req);

#endif
