/*
 * $Id$
 * Author: Drew Mazurek
 *
 * Command line service layer for DRR actions.
 *
 * Copyright (c) 2008, Stanford University
 */

#include <malloc.h>
#include <stdio.h>
#include <string.h>

#include "drr_cli.h"
#include "drr.h"
#include "or_data_types.h"
#include "or_utils.h"
#include "nf2/nf2.h"
#include "nf2/nf2util.h"

static void drr_cli_show_stats(router_state *router, int fd);
static void send_wrapper(int fd, char *text);

void drr_register_cli_commands(node **cli_commands) {

    register_cli_command(cli_commands, "drr ?", &drr_cli_help);
    register_cli_command(cli_commands, "drr show", &drr_cli_show);
    register_cli_command(cli_commands, "drr reset", &drr_cli_help_reset);
    register_cli_command(cli_commands, "drr reset ?",
                         &drr_cli_help_reset);
    register_cli_command(cli_commands, "drr reset stats", &drr_cli_reset_stats);
    register_cli_command(cli_commands, "drr set ?", &drr_cli_help_set);
    register_cli_command(cli_commands, "drr set slow", &drr_cli_set_slow);
    register_cli_command(cli_commands, "drr set slow ?",
                         &drr_cli_help_set_slow);
    register_cli_command(cli_commands, "drr set weight", &drr_cli_set_weight);
    register_cli_command(cli_commands, "drr set weight ?",
                         &drr_cli_help_set_weight);
    register_cli_command(cli_commands, "drr set quantum",
                         &drr_cli_set_quantum);
    register_cli_command(cli_commands, "drr set quantum ?",
                         &drr_cli_help_set_quantum);
    register_cli_command(cli_commands, "drr set policy ?",
                         &drr_cli_help_set_policy);
    register_cli_command(cli_commands, "drr set policy tos",
                         &drr_cli_set_policy_tos);
    register_cli_command(cli_commands, "drr set policy port",
                         &drr_cli_set_policy_port);
    register_cli_command(cli_commands, "drr set tos", &drr_cli_set_tos);
    register_cli_command(cli_commands, "drr set tos ?", &drr_cli_help_set_tos);
}

void drr_cli_show(router_state *router, cli_request *req) {

    drr_cli_show_stats(router, req->sockfd);
}

static void drr_cli_show_stats(router_state *router, int fd) {

    int value;
    char line[82];
    char *policy_string;
    struct nf2device *nf2;
    int i;

    nf2 = &router->netfpga;

    send_wrapper(fd,"--- DRR Settings and Statistics ---\n");

    value = drr_get_quantum(router);
    snprintf(line,82,"Quantum size: %d bytes\n",value);
    send_wrapper(fd,line);

    value = drr_get_slow_factor(router);
    snprintf(line,82,"Slowing factor: %d\n",value);
    send_wrapper(fd,line);

    value = drr_get_policy(router);
    policy_string = drr_get_policy_string(router);
    
    if(value == DRR_POLICY_PORT) {
        snprintf(line,82,"Classification policy: by input port (%s)\n",
                 policy_string);
        send_wrapper(fd,line);
    } else if(value == DRR_POLICY_TOS) {
        snprintf(line,82,"Classification policy: by IP ToS field (%s)\n",
                     policy_string);
        send_wrapper(fd,line);
        for(i=0;i<DRR_TOS_QUEUES;i++) {
            value = drr_get_tos_queue(router,i);
            snprintf(line,82,"  queue %d ToS value: %x\n",i,value);
            send_wrapper(fd,line);
        }
    } else {
        send_wrapper(fd,"Classification policy: unknown\n");
    }

    if(policy_string) {
        free(policy_string);
    }

    for(i=1;i<=3;i++) {
        value = drr_get_oq_state(router,i);
        snprintf(line,82,"Current output queue FSM %d state: %d\n",i,value);
        send_wrapper(fd,line);
    }

    value = drr_get_request_fifo_empty(router);
    snprintf(line,82,"DRR Request Fifo Empty: %d\n",value);
    send_wrapper(fd,line);

    value = drr_get_classifier_state(router);
    snprintf(line,82,"Current classifier FSM state: %d\n",value);
    send_wrapper(fd,line);

    value = drr_get_slow_counter(router);
    snprintf(line,82,"Slow factor counter: %d\n",value);
    send_wrapper(fd,line);

    /* Now show all the queue-specific stuff. */
    for(i=0;i<DRR_QUEUES;i++) {
        snprintf(line,82,"Statistics for queue %d:\n",i);
        send_wrapper(fd,line);

        value = drr_get_drops(router,i);
        snprintf(line,82,"  drops: %d packets\n",value);
        send_wrapper(fd,line);

        value = drr_get_increment(router,i);
        snprintf(line,82,"  credit per round: %d bytes\n", value);
        send_wrapper(fd,line);

        value = drr_get_occupancy(router,i);
        snprintf(line,82,"  occupancy: %d bytes\n",value * 64);
        send_wrapper(fd,line);

        value = drr_get_classified_packets(router,i);
        snprintf(line,82,"  total packets classified: %d\n",value);
        send_wrapper(fd,line);
    }
}

void drr_cli_set_slow(router_state *router, cli_request *req) {

    char line[82];
    int factor;

    if(sscanf(req->command, "drr set slow %d", &factor) != 1) {
        send_wrapper(req->sockfd, "Failure reading arguments.\n");
        return;
    }

    if(factor <= 0) {
        send_wrapper(req->sockfd, "Slow factor must be greater than 0.\n");
        return;
    }

    drr_set_slow_factor(router,factor);
    
    snprintf(line,82,"Set slow factor to %d\n",factor);
    send_wrapper(req->sockfd,line);
}

void drr_cli_set_weight(router_state *router, cli_request *req) {

    char line[82];
    int queue;
    float weight;

    if(sscanf(req->command, "drr set weight %d %f", &queue, &weight) != 2) {
        send_wrapper(req->sockfd, "Failure reading arguments.\n");
        return;
    }

    if(queue < 0 || queue >= DRR_QUEUES) {
        send_wrapper(req->sockfd,"Error: Invalid queue\n");
        return;
    }

    if(weight <= 0) {
        send_wrapper(req->sockfd,"Error: Weight must be greater than 0.\n");
        return;
    }

    drr_set_weight(router, queue, weight);

    snprintf(line,82,"Set weight for queue %d to %.1f\n",queue,weight);
    send_wrapper(req->sockfd,line);
}

void drr_cli_set_quantum(router_state *router, cli_request *req) {

    char line[82];
    int quantum;

    if(sscanf(req->command, "drr set quantum %d", &quantum) != 1) {
        send_wrapper(req->sockfd, "Failure reading arguments.\n");
        return;
    }

    if(quantum < 0) {
        send_wrapper(req->sockfd, "Error: Quantum must be greater than 0.\n");
        return;
    }

    drr_set_quantum(router, quantum);

    snprintf(line,82,"Set DRR quantum to %d bytes\n",quantum);
    send_wrapper(req->sockfd,line);
}

void drr_cli_set_policy_tos(router_state *router, cli_request *req) {

    drr_set_policy(router, DRR_POLICY_TOS);
    send_wrapper(req->sockfd,
                 "Set DRR policy to IP ToS-based classification.\n");
}

void drr_cli_set_policy_port(router_state *router, cli_request *req) {

    drr_set_policy(router, DRR_POLICY_PORT);
    send_wrapper(req->sockfd, "Set DRR policy to port-based classification\n");
}

void drr_cli_set_tos(router_state *router, cli_request *req) {

    char line[82];
    int queue;
    int tos;

    if(sscanf(req->command, "drr set tos %d %d\n", &queue, &tos) != 2) {
        send_wrapper(req->sockfd, "Failure reading arguments.\n");
        return;
    }

    if(tos < 0 || tos > 255) {
        send_wrapper(req->sockfd,"Error: ToS value must be between 0 and 255.\n");
        return;
    }

    if(queue < 0 || queue > DRR_TOS_QUEUES) {
        snprintf(line,82,"Error: invalid queue %d\n",queue);
        send_wrapper(req->sockfd,line);
        return;
    }

    drr_set_tos_queue(router,queue,tos);
    snprintf(line,82,"Set queue %d to ToS %d\n",queue,tos);
    send_wrapper(req->sockfd,line);
}

void drr_cli_reset_stats(router_state *router, cli_request *req) {

    drr_reset_stats(router);

    send_wrapper(req->sockfd,"DRR statistics reset.\n");
}

/* DRR Help Functions */
void drr_cli_help(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr <show|set|reset>\n");
}

void drr_cli_help_reset(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr reset stats\n");
}

void drr_cli_help_set(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr set <slow|weight|quantum|policy|tos>\n");
}

void drr_cli_help_set_slow(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr set slow <slow factor>\n");
}

void drr_cli_help_set_weight(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr set weight <queue> <weight>\n");
}

void drr_cli_help_set_quantum(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr set quantum <quantum>\n");
}

void drr_cli_help_set_policy(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr set policy <port|tos>\n");
}

void drr_cli_help_set_tos(router_state *router, cli_request *req) {

    send_wrapper(req->sockfd,"usage: drr set tos <ToS queue> <IP ToS value>\n");
}

/* Wrapper to send() that accepts a null-terminated string. */
static void send_wrapper(int fd, char *text) {

    send_to_socket(fd, text, strlen(text));
}
