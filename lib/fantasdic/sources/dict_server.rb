# Fantasdic
# Copyright (C) 2006 - 2007 Mathieu Blondel
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

module Fantasdic
module Source

    class DictServer < Base
        authors ["Mathieu Blondel"]
        title  _("DICT dictionary server")
        description _("Look up words using a DICT dictionary server.")
        license Fantasdic::GPL
        copyright "Copyright (C) 2006 - 2007 Mathieu Blondel"

        class ServerInfoDialog < UI::GladeBase
            include GetText
            GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

            def initialize(server, port, username="", password="")
                super("server_infos_dialog.glade")                
                @dialog.title = _("Server details")
                @server = server
                @port = port
                @username = username
                @password = password
                initialize_signals
                show_server_info
            end

            def initialize_signals
                @dialog.signal_connect("delete-event") { @dialog.hide }
                @close_button.signal_connect("clicked") { @dialog.hide }
            end

            def show_server_info
                begin
                    dict = DICTClient.new(@server, @port, $DEBUG)

                    unless @username.empty? or @password.empty?
                        dict.auth(@username, @password)
                    end

                    @textview.buffer.text = dict.show_server

                    dict.disconnect
                rescue DICTClient::ConnectionError
                    @textview.buffer.text = _("Could not connect to %s") \
                                    % @server
                end
            end
        end

        class ConfigWidget < Base::ConfigWidget
            def initialize(*arg)
                super(*arg)
                initialize_ui
                initialize_data
                initialize_signals                
            end

            def to_hash
                checks = [
                    [@server_entry.text.empty?, _("Server missing.")],
                    [@port_entry.text.empty?, _("Port missing.")],

                    [(@serv_auth_checkbutton.active? and
                    @login_entry.text.empty?), _("Username missing.")],
                    [(@serv_auth_checkbutton.active? and
                      @password_entry.text.empty?), _("Password missing.")]
                ]

                checks.each do |expr, msg|
                    if expr == true
                        raise Source::SourceError, msg
                    end
                end

                hash = {}
                hash[:server] = @server_entry.text
                hash[:port] = @port_entry.text
                hash[:auth] = @serv_auth_checkbutton.active?
                hash[:login] = @login_entry.text
                hash[:password] = @password_entry.text
                hash
            end

            private

            def initialize_ui
                server_label = Gtk::Label.new(_("_Server:"), true)
                server_label.xalign = 0
                @server_entry = Gtk::Entry.new
                @server_info_button = Gtk::Button.new
                img = Gtk::Image.new(Gtk::Stock::INFO, Gtk::IconSize::BUTTON)
                @server_info_button.image = img

                hbox = Gtk::HBox.new
                hbox.spacing = 5
                hbox.pack_start(@server_entry)                
                hbox.pack_start(@server_info_button, false)

                port_label = Gtk::Label.new(_("_Port:"), true)
                port_label.xalign = 0
                @port_entry = Gtk::Entry.new

                table = Gtk::Table.new(2, 2)
                table.row_spacings = 6
                table.column_spacings = 12
                # attach(child, left, right, top, bottom,
                #        xopt = Gtk::EXPAND|Gtk::FILL,
                #        yopt = Gtk::EXPAND|Gtk::FILL, xpad = 0, ypad = 0)
                table.attach(server_label, 0, 1, 0, 1, Gtk::FILL, Gtk::FILL)
                table.attach(port_label, 0, 1, 1, 2, Gtk::FILL, Gtk::FILL)
                table.attach(hbox, 1, 2, 0, 1)
                table.attach(@port_entry, 1, 2, 1, 2)

                self.pack_start(table)

                self.pack_start(Gtk::HSeparator.new)

                @serv_auth_checkbutton = \
                    Gtk::CheckButton.new(_("Server _requires authentication"),
                                         true)

                self.pack_start(@serv_auth_checkbutton)

                login_label = Gtk::Label.new(_("_Username:"), true)
                login_label.xalign = 0
                @login_entry = Gtk::Entry.new

                password_label = Gtk::Label.new(_("Pass_word:"), true)
                password_label.xalign = 0
                @password_entry = Gtk::Entry.new

                @auth_table = Gtk::Table.new(2, 2)
                @auth_table.row_spacings = 6
                @auth_table.column_spacings = 12
                # attach(child, left, right, top, bottom,
                #        xopt = Gtk::EXPAND|Gtk::FILL,
                #        yopt = Gtk::EXPAND|Gtk::FILL, xpad = 0, ypad = 0)
                @auth_table.attach(login_label, 0, 1, 0, 1, Gtk::FILL,
                                   Gtk::FILL)
                @auth_table.attach(password_label, 0, 1, 1, 2, Gtk::FILL,
                                   Gtk::FILL)
                @auth_table.attach(@login_entry, 1, 2, 0, 1)
                @auth_table.attach(@password_entry, 1, 2, 1, 2)

                self.pack_start(@auth_table)
            end

            def initialize_signals
                [@server_entry, @port_entry, @login_entry, @password_entry].
                each do |entry|
                    entry.signal_connect("activate") do
                        @last_server = @server_entry.text
                        @last_port = @port_entry.text
                        @last_login = @login_entry.text
                        @last_password = @password_entry.text
                        @on_databases_changed_block.call
                    end
                end

                @serv_auth_checkbutton.signal_connect("toggled") do
                    @auth_table.sensitive = @serv_auth_checkbutton.active?
                end

                @last_server = @server_entry.text
                @last_port = @port_entry.text
                @last_login = @login_entry.text
                @last_password = @password_entry.text
                
                [[@server_entry, "@last_server"],
                 [@port_entry, "@last_port"],
                 [@login_entry, "@last_login"],
                 [@password_entry, "@last_login"]].each do |entry, last|
                    entry.signal_connect("focus-out-event") do |w, event|
                        if instance_variable_get(last) != entry.text
                            instance_variable_set(last,entry.text)
                            @on_databases_changed_block.call
                        end
                        false
                    end
                end

                @server_info_button.signal_connect("clicked") do
                    show_server_info_dialog
                end
            end

            def show_server_info_dialog
                if @server_entry.text.empty?
                    UI::ErrorDialog.new(@parent_dialog, _("Server missing."))
                    return false
                end

                if @port_entry.text.empty?
                    UI::ErrorDialog.new(@parent_dialog, _("Port missing."))
                    return false
                end

                if @serv_auth_checkbutton.active?
                    ServerInfoDialog.new(@server_entry.text,
                                         @port_entry.text,
                                         @login_entry.text,
                                         @password_entry.text)
                else
                    ServerInfoDialog.new(@server_entry.text,
                                         @port_entry.text)
                end
            end

            def initialize_data
                if @config and @config[:server] and @config[:port]
                    @server_entry.text = @config[:server]
                    @port_entry.text = @config[:port]
                    @serv_auth_checkbutton.active = @config[:auth]
                    @auth_table.sensitive = @config[:auth]
                    @login_entry.text = @config[:login] if @config[:login]
                    @password_entry.text = @config[:password] \
                        if @config[:password]
                else
                    @auth_table.sensitive = false
                    @server_entry.text = "dict.org"
                    @port_entry.text = DICTClient::DEFAULT_PORT.to_s
                end
            end
        end        

        def initialize(*args)
            super(*args)            
        end

        def open
            # The mechanism to hold connections is implememented in DICTClient.
            # DICTClient::get_connection returns an active connection if
            # available or create a new one.
            DICTClient.close_long_connections
            
            begin
                if @config[:auth]
                    @dict = DICTClient.get_connection(Fantasdic::TITLE,
                                                      @config[:server],
                                                      @config[:port],
                                                      @config[:login],
                                                      @config[:password])
                else 
                    @dict = DICTClient.get_connection(Fantasdic::TITLE,
                                                      @config[:server],
                                                      @config[:port])
                end
            rescue DICTClient::ConnectionError, Errno::ECONNRESET,
                   DICTClient::ConnectionLost => e
                DICTClient.close_all_connections                
                raise Source::SourceError,
                      _("Could not connect to %s") % @config[:server]
            end
        end

        def available_databases
            begin
                return @dict.show_db
            rescue DICTClient::ConnectionLost, Errno::EPIPE
                DICTClient.close_active_connection
                raise Source::SourceError,
                      _("Could not connect to %s") % @config[:server]
            end
        end

        def available_strategies
            begin
                available_strategies = @dict.show_strat
                hash = {}
                available_strategies.each do |name, description|
                    hash[name] = description
                end
                return hash
            rescue DICTClient::ConnectionLost, Errno::EPIPE
                DICTClient.close_active_connection
                raise Source::SourceError,
                      _("Could not connect to %s") % @config[:server]
            end
        end

        def database_info(dbname)
            begin
                res = @dict.show_info(dbname)
                return res
            rescue DICTClient::ConnectionLost, Errno::EPIPE
                DICTClient.close_active_connection
                raise Source::SourceError,
                      _("Could not connect to %s") % @config[:server]
            end
        end

        def define(db, word)
            begin
                return @dict.define(db, word)
            rescue DICTClient::ConnectionLost, Errno::EPIPE
                DICTClient.close_active_connection
                raise Source::SourceError, _("Connection with server lost.")
            end
        end

        def match(db, strat, word)
            begin
                return @dict.match(db, strat, word)
            rescue DICTClient::ConnectionLost, Errno::EPIPE
                DICTClient.close_active_connection
                raise Source::SourceError, _("Connection with server lost.")
            end
        end

        def connecting_to_source_str
            _("Waiting for %s...") % @config[:server]
        end

        def transferring_data_str
            _("Transferring data from %s...") % @config[:server]
        end

    end

end
end

Fantasdic::Source::Base.register_source(Fantasdic::Source::DictServer)