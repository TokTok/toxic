/*  toxic.h
 *
 *
 *  Copyright (C) 2024 Toxic All Rights Reserved.
 *
 *  This file is part of Toxic.
 *
 *  Toxic is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Toxic is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Toxic.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef TOXIC_H
#define TOXIC_H

#ifndef NCURSES_WIDECHAR
#define NCURSES_WIDECHAR 1
#endif

#ifndef TOXICVER
#define TOXICVER "NOVERS"    /* Use the -D flag to set this */
#endif

#ifndef SIGWINCH
#define SIGWINCH 28
#endif

#ifndef SIGINT
#define SIGINT 2
#endif

#include <stdbool.h>
#include <curses.h>

#include <tox/tox.h>

#ifdef TOX_EXPERIMENTAL
#include <toxcore/tox_private.h>
#endif

#include "settings.h"
#include "toxic_constants.h"

typedef struct Run_Options {
    bool use_ipv4;
    bool force_tcp;
    bool disable_local_discovery;
    bool debug;
    bool default_locale;
    bool use_custom_data;
    bool no_connect;
    bool encrypt_data;
    bool unencrypt_data;

    char nameserver_path[MAX_STR_SIZE];
    char config_path[MAX_STR_SIZE];
    char nodes_path[MAX_STR_SIZE];

    bool logging;
    FILE *log_fp;

    char proxy_address[256];
    uint8_t proxy_type;
    uint16_t proxy_port;

    uint16_t tcp_port;
} Run_Options;

typedef struct Client_Data {
    bool is_encrypted;
    char pass[MAX_PASSWORD_LEN + 1];
    int  pass_len;
    char *data_path;
    char *block_path;
} Client_Data;

typedef struct ToxAV ToxAV;
typedef struct ToxWindow ToxWindow;

typedef struct Toxic {
    Tox   *tox;
#ifdef AUDIO
    ToxAV *av;
#endif
    Client_Data   client_data;
    Client_Config *c_config;
    Run_Options   *run_opts;

    ToxWindow     *home_window;
} Toxic;

void lock_status(void);
void unlock_status(void);

void flag_interface_refresh(void);

/* Sets ncurses refresh rate. Lower values make it refresh more often. */
void set_window_refresh_rate(size_t refresh_rate);

void exit_toxic_success(Toxic *toxic) __attribute__((__noreturn__));
void exit_toxic_err(const char *errmsg, int errcode) __attribute__((__noreturn__));

int store_data(const Toxic *toxic);

/* callbacks */
void on_friend_request(Tox *tox, const uint8_t *public_key, const uint8_t *data, size_t length, void *userdata);
void on_friend_connection_status(Tox *tox, uint32_t friendnumber, Tox_Connection status, void *userdata);
void on_friend_message(Tox *tox, uint32_t friendnumber, Tox_Message_Type type, const uint8_t *string, size_t length,
                       void *userdata);
void on_friend_name(Tox *tox, uint32_t friendnumber, const uint8_t *string, size_t length, void *userdata);
void on_friend_status(Tox *tox, uint32_t friendnumber, Tox_User_Status status, void *userdata);
void on_friend_status_message(Tox *tox, uint32_t friendnumber, const uint8_t *string, size_t length, void *userdata);
void on_friend_added(Toxic *toxic, uint32_t friendnumber, bool sort);
void on_conference_message(Tox *tox, uint32_t conferencenumber, uint32_t peernumber, Tox_Message_Type type,
                           const uint8_t *message, size_t length, void *userdata);
void on_conference_invite(Tox *tox, uint32_t friendnumber, Tox_Conference_Type type, const uint8_t *conference_pub_key,
                          size_t length, void *userdata);
void on_conference_peer_list_changed(Tox *tox, uint32_t conferencenumber, void *userdata);
void on_conference_peer_name(Tox *tox, uint32_t conferencenumber, uint32_t peernumber, const uint8_t *name,
                             size_t length, void *userdata);
void on_conference_title(Tox *tox, uint32_t conferencenumber, uint32_t peernumber, const uint8_t *title, size_t length,
                         void *userdata);
void on_file_chunk_request(Tox *tox, uint32_t friendnumber, uint32_t filenumber, uint64_t position, size_t length,
                           void *userdata);
void on_file_recv_chunk(Tox *tox, uint32_t friendnumber, uint32_t filenumber, uint64_t position, const uint8_t *data,
                        size_t length, void *userdata);
void on_file_recv_control(Tox *tox, uint32_t friendnumber, uint32_t filenumber, Tox_File_Control control,
                          void *userdata);
void on_file_recv(Tox *tox, uint32_t friendnumber, uint32_t filenumber, uint32_t kind, uint64_t file_size,
                  const uint8_t *filename, size_t filename_length, void *userdata);
void on_friend_typing(Tox *tox, uint32_t friendnumber, bool is_typing, void *userdata);
void on_friend_read_receipt(Tox *tox, uint32_t friendnumber, uint32_t receipt, void *userdata);
void on_lossless_custom_packet(Tox *tox, uint32_t friendnumber, const uint8_t *data, size_t length, void *userdata);
void on_group_invite(Tox *tox, uint32_t friendnumber, const uint8_t *invite_data, size_t length,
                     const uint8_t *group_name,
                     size_t group_name_length, void *userdata);
void on_group_message(Tox *tox, uint32_t groupnumber, uint32_t peernumber, TOX_MESSAGE_TYPE type,
                      const uint8_t *message, size_t length, uint32_t message_id, void *userdata);
void on_group_private_message(Tox *tox, uint32_t groupnumber, uint32_t peernumber, TOX_MESSAGE_TYPE type,
                              const uint8_t *message, size_t length,
                              void *userdata);
void on_group_peer_join(Tox *tox, uint32_t groupnumber, uint32_t peernumber, void *userdata);
void on_group_peer_exit(Tox *tox, uint32_t groupnumber, uint32_t peer_id, Tox_Group_Exit_Type exit_type,
                        const uint8_t *nick,
                        size_t nick_len, const uint8_t *partmsg, size_t length, void *userdata);
void on_group_topic_change(Tox *tox, uint32_t groupnumber, uint32_t peernumber, const uint8_t *topic, size_t length,
                           void *userdata);
void on_group_peer_limit(Tox *tox, uint32_t groupnumber, uint32_t peer_limit, void *userdata);
void on_group_privacy_state(Tox *tox, uint32_t groupnumber, Tox_Group_Privacy_State privacy_state, void *userdata);
void on_group_topic_lock(Tox *tox, uint32_t groupnumber, Tox_Group_Topic_Lock topic_lock, void *userdata);
void on_group_password(Tox *tox, uint32_t groupnumber, const uint8_t *password, size_t length, void *userdata);
void on_group_nick_change(Tox *tox, uint32_t groupnumber, uint32_t peernumber, const uint8_t *newname, size_t length,
                          void *userdata);
void on_group_status_change(Tox *tox, uint32_t groupnumber, uint32_t peernumber, TOX_USER_STATUS status,
                            void *userdata);
void on_group_self_join(Tox *tox, uint32_t groupnumber, void *userdata);
void on_group_rejected(Tox *tox, uint32_t groupnumber, Tox_Group_Join_Fail type, void *userdata);
void on_group_moderation(Tox *tox, uint32_t groupnumber, uint32_t source_peernum, uint32_t target_peernum,
                         Tox_Group_Mod_Event type, void *userdata);
void on_group_voice_state(Tox *tox, uint32_t groupnumber, Tox_Group_Voice_State voice_state, void *userdata);

#endif /* TOXIC_H */
