/*
 * $Id$
 * Author: Drew Mazurek
 *
 * Functions for monitoring and controlling DRR queue settings.
 *
 * Copyright (c) 2008, Stanford University
 */

#ifndef _I_DRR_H
#define _I_DRR_H

#define DRR_POLICY_PORT 0
#define DRR_POLICY_TOS 1

#define DRR_DEFAULT_QUANTUM 512
#define DRR_DEFAULT_POLICY DRR_POLICY_PORT
#define DRR_DEFAULT_WEIGHT 1
#define DRR_CPU_QUEUE 4
#define DRR_CPU_DEFAULT_WEIGHT 10
#define DRR_QUEUES 5
#define DRR_TOS_QUEUES 3

#include "or_data_types.h"

struct router_state;

void drr_init(struct router_state *router);
void drr_reset_stats(struct router_state *router);

int drr_get_drops(struct router_state *router, int queue);
void drr_reset_drops(struct router_state *router, int queue);

int drr_get_slow_factor(struct router_state *router);
void drr_set_slow_factor(struct router_state *router, int factor);

int drr_get_quantum(struct router_state *router);
void drr_set_quantum(struct router_state *router, int quantum);

void drr_set_weight(struct router_state *router, int queue, float weight);
float drr_get_weight(struct router_state *router, int queue);

int drr_get_increment(struct router_state *router, int queue);

int drr_get_occupancy(struct router_state *router, int queue);

int drr_get_oq_state(struct router_state *router, int fsm_num);
int drr_get_request_fifo_empty(struct router_state *router);

int drr_get_classified_packets(struct router_state *router, int queue);
void drr_reset_classified_packets(struct router_state *router, int queue);

int drr_get_policy(struct router_state *router);
void drr_set_policy(struct router_state *router, int policy);

int drr_get_tos_queue(struct router_state *router, int queue);
void drr_set_tos_queue(struct router_state *router, int queue, int tos);

char *drr_get_policy_string(struct router_state *router);

int drr_get_classifier_state(struct router_state *router);

int drr_get_slow_counter(struct router_state *router);

#endif
