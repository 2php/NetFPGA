/*
 * $Id$
 * Author: Drew Mazurek
 *
 * Functions for monitoring and controlling DRR queue settings.
 *
 * Copyright (c) 2008, Stanford University
 */

#include <malloc.h>
#include <stdio.h>
#include <string.h>

#include "drr.h"
#include "nf2/nf2.h"
#include "nf2/nf2util.h"
#include "drr_reg_defines.h"

#ifdef _DEBUG_
#define Debug(x, args...) printf(x, ## args)
#endif

/* Initialize the DRR registers and settings. */
void drr_init(struct router_state *router) {

    int i;

    Debug("drr_init: initializing DRR settings\n");

    drr_set_slow_factor(router,1);
    drr_set_quantum(router,DRR_DEFAULT_QUANTUM);

    drr_set_policy(router,DRR_DEFAULT_POLICY);

    for(i=0;i<DRR_QUEUES;i++) {
        drr_set_weight(router,i,DRR_DEFAULT_WEIGHT);
        router->drr_weights[i] = 1;
    }

    drr_set_weight(router,DRR_CPU_QUEUE,DRR_CPU_DEFAULT_WEIGHT);
    router->drr_weights[DRR_CPU_QUEUE] = DRR_CPU_DEFAULT_WEIGHT;

    for(i=0;i<DRR_TOS_QUEUES;i++) {
        drr_set_tos_queue(router,i,0);
    }

    drr_reset_stats(router);
}

/* Resets all statistics counters. */
void drr_reset_stats(struct router_state *router) {

    int i;

    for(i=0;i<DRR_QUEUES;i++) {
        drr_reset_drops(router,i);
        drr_reset_classified_packets(router,i);
    }
}

/* Gets the number of packets dropped by the given queue. */
int drr_get_drops(struct router_state *router, int queue) {

    int drops;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue >= 0 && queue < DRR_QUEUES) {
        readReg(nf2, DRR_OQ_QUEUE0_NUM_DROP_REG + queue*4, &drops);
        Debug("drr_reset_drops: reading dropped packets for queue %d\n",queue);
    } else {
        drops = -1;
    }

    return drops;
}

/* Resets the counter for dropped packets for the given queue. */
void drr_reset_drops(struct router_state *router, int queue) {

    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue >= 0 && queue < DRR_QUEUES) {
        Debug("drr_reset_drops: resetting dropped packets for queue %d\n",
              queue);
        writeReg(nf2, DRR_OQ_QUEUE0_NUM_DROP_REG + queue*4, 0);
    }
}

/* Gets the rate-limiting factor. */
int drr_get_slow_factor(struct router_state *router) {

    int slow_factor;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    Debug("drr_get_slow_factor: getting slow factor\n");

    readReg(nf2, DRR_OQ_SLOW_FACTOR_REG, &slow_factor);

    return slow_factor;
}

/* Sets the rate-limiting factor. */
void drr_set_slow_factor(struct router_state *router, int factor) {

    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(factor < 0) {
        return;
    }

    Debug("drr_set_slow_factor: setting slow factor to %d\n",factor);

    writeReg(nf2, DRR_OQ_SLOW_FACTOR_REG, factor);
}

/* Gets the DRR quantum size. */
int drr_get_quantum(struct router_state *router) {

    struct nf2device *nf2;
    int quantum;

    nf2 = &router->netfpga;

    readReg(nf2, DRR_OQ_QUANTUM_REG, &quantum);

    return quantum;
}

/* Sets the DRR quantum size. */
void drr_set_quantum(struct router_state *router, int quantum) {

    struct nf2device *nf2;
    int i;

    nf2 = &router->netfpga;

    if(quantum < 0) {
        return;
    }

    Debug("drr_set_quantum: setting quantum size to %d\n",quantum);

    /* Update the quantum register. */
    writeReg(nf2, DRR_OQ_QUANTUM_REG, quantum);

    /* Update the credit amounts for each queue. */
    for(i=0;i<DRR_QUEUES;i++) {
        writeReg(nf2, DRR_OQ_QUEUE0_CREDIT_REG + i*4,
            router->drr_weights[i] * quantum);
    }
}

/* Sets the DRR weight factor for the given queue. */
void drr_set_weight(struct router_state *router, int queue, float weight) {

    struct nf2device *nf2;
    int quantum;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_QUEUES || weight < 0) {
        return;
    }

    router->drr_weights[queue] = weight;

    Debug("drr_set_weight: set weight for queue %d to %f\n",queue,weight);

    readReg(nf2, DRR_OQ_QUANTUM_REG, &quantum);

    writeReg(nf2, DRR_OQ_QUEUE0_CREDIT_REG + queue*4,
        quantum * weight);
}

/* Gets the DRR weight factor for the given queue. */
float drr_get_weight(struct router_state *router, int queue) {

    return router->drr_weights[queue];
}

/* Gets the DRR increment value for the given queue. */
int drr_get_increment(struct router_state *router, int queue) {

    int increment;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_QUEUES) {
        return -1;
    }

    readReg(nf2, DRR_OQ_QUEUE0_CREDIT_REG + queue*4, &increment);

    return increment;
}

/* Gets the queue occupancy for the given queue in 64-bit words. */
int drr_get_occupancy(struct router_state *router, int queue) {

    int occupancy;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_QUEUES) {
        return -1;
    }

    readReg(nf2, DRR_OQ_QUEUE0_OCCUPANCY_REG + queue*4, &occupancy);

    return occupancy;
}

/* Debugging function to get the state of the given DRR FSM. */
int drr_get_oq_state(struct router_state *router, int fsm_num) {

    struct nf2device *nf2;
    int state;

    nf2 = &router->netfpga;

    if(fsm_num < 1 || fsm_num > 3) {
        return -1;
    }

    readReg(nf2, DRR_OQ_STATE1_REG + (fsm_num-1)*4, &state);

    return state;
}

/* Debugging function to get the state of the FIFO.  Returns 1 if the
 * queue is empty, 0 otherwise. */
int drr_get_request_fifo_empty(struct router_state *router) {

    struct nf2device *nf2;
    int value;

    nf2 = &router->netfpga;

    readReg(nf2, DRR_OQ_REQUEST_FIFO_EMPTY_REG, &value);

    return value;
}

/* Statistics function to get the number of packets classified into the
 * given queue. */
int drr_get_classified_packets(struct router_state *router, int queue) {

    struct nf2device *nf2;
    int num_packets;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_QUEUES) {
        return -1;
    }

    readReg(nf2, DRR_QCLASS_Q0_NUM_PKTS_REG + queue*4, &num_packets);

    return num_packets;
}

/* Resets the counter for packets classified into the given queue. */
void drr_reset_classified_packets(struct router_state *router, int queue) {

    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_QUEUES) {
        return;
    }

    writeReg(nf2, DRR_QCLASS_Q0_NUM_PKTS_REG + queue*4, 0);
}

/* Gets the classification policy. */
int drr_get_policy(struct router_state *router) {

    int policy;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    readReg(nf2, DRR_QCLASS_POLICY_REG, &policy);

    return policy;
}

/* Sets the classification policy. */
void drr_set_policy(struct router_state *router, int policy) {

    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(policy != DRR_POLICY_PORT && policy != DRR_POLICY_TOS) {
        Debug("drr_set_policy: invalid policy: %d\n",policy);
        return;
    }

    writeReg(nf2, DRR_QCLASS_POLICY_REG, policy);
}

/* Gets the IP ToS value for the given queue. */
int drr_get_tos_queue(struct router_state *router, int queue) {

    int tos;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_TOS_QUEUES) {
        return -1;
    }

    readReg(nf2, DRR_QCLASS_Q0_TOS_REG + queue*4, &tos);

    return tos;
}

/* Sets the IP ToS value for the given queue. */
void drr_set_tos_queue(struct router_state *router, int queue, int tos) {

    struct nf2device *nf2;

    nf2 = &router->netfpga;

    if(queue < 0 || queue >= DRR_TOS_QUEUES || (tos != DRR_POLICY_PORT
       && tos != DRR_POLICY_TOS)) {

        return;
    }

    writeReg(nf2, DRR_QCLASS_Q0_TOS_REG + queue*4, tos);
}

/* Debugging function to get the state of the DRR classifier. */
int drr_get_classifier_state(struct router_state *router) {

    int state;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    readReg(nf2, DRR_QCLASS_STATE_REG, &state);

    return state;
}

/* Gets the current slow factor counter value. */
int drr_get_slow_counter(struct router_state *router) {

    int count;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    readReg(nf2, DRR_OQ_COUNT_REG, &count);

    return count;
}

/* Gets the current policy string from the hardware.  Returns a pointer to
 * dynamically-allocated memory that must be freed, or NULL. */
char *drr_get_policy_string(struct router_state *router) {

    char *policy;
    uint32_t policy_word;
    int policy_num;
    struct nf2device *nf2;

    nf2 = &router->netfpga;

    readReg(nf2, DRR_QCLASS_POLICY_REG, &policy_num);

    if(policy_num != DRR_POLICY_PORT && policy_num != DRR_POLICY_TOS) {
        return NULL;
    }

    readReg(nf2, DRR_QCLASS_STRING_POLICY0_REG + policy_num*4, &policy_word);

    policy_word = ntohl(policy_word);

    policy = malloc(5 * sizeof(char));
    if(!policy) {
        fprintf(stderr,"drr_get_policy_string: error allocating memory\n");
        return NULL;
    }

    strncpy(policy, (char *)&policy_word, 4);

    policy[4] = '\0';

    return policy;
}
