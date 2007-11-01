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

require "thread"

module Gtk
    # Thread-safety stuff.
    # Loosely based on booh, by Guillaume Cottenceau.

    PENDING_CALLS_MUTEX = Mutex.new
    PENDING_CALLS = []

    def self.thread_protect(&proc)
        if Thread.current == Thread.main
            proc.call
        else
            PENDING_CALLS_MUTEX.synchronize do
                PENDING_CALLS << proc
            end
        end
    end

    def self.thread_flush
        if PENDING_CALLS_MUTEX.try_lock
            for closure in PENDING_CALLS
                closure.call
            end
            PENDING_CALLS.clear
            PENDING_CALLS_MUTEX.unlock
        end
    end

    def self.init_thread_protect
        Gtk.timeout_add(100) do
            PENDING_CALLS_MUTEX.synchronize do
                for closure in PENDING_CALLS
                    closure.call
                end
                PENDING_CALLS.clear
            end
            true
        end
    end
end

class Gtk::TreeView
    def has_row_selected?
        self.selection.selected_each { return true }
        return false
    end
    
    def selected_iter
        self.selection.selected
    end

    def selected_iters
        array = []
        self.selection.selected_each do |model, path, iter|
            array << iter
        end
        array
    end
end


module Gtk::TreeModel
    def nb_rows
        count = 0
        self.each { count += 1 }
        count
    end
    alias :n_rows :nb_rows

    def empty?
        nb_rows == 0
    end    
end

class Gtk::ListStore
    def remove_last
        path = Gtk::TreePath.new((self.nb_rows - 1).to_s)
        last_iter = self.get_iter(path)
        self.remove(last_iter)
    end
end

class Gtk::ActionGroup
    def [](x)
        get_action(x)
    end
end

class Pango::Layout
    def size_points
        self.size.collect { |v| v / Pango::SCALE }
    end

    def width_points
        self.size[0] / Pango::SCALE
    end

    def height_points
        self.size[1] / Pango::SCALE
    end

    def width_points=(width)
        self.width = width * Pango::SCALE
    end
end

class Pango::FontDescription
    def size_points
        self.size / Pango::SCALE
    end

    def size_points=(size)
        self.size = size * Pango::SCALE
    end
end

class Gtk::TextIter
    def backward_case_insensitive_search(str, flags, limit=nil)
        unless limit
            limit = self.buffer.start_iter
        end

        txt = self.buffer.get_slice(limit, self)

        match = /(#{Regexp.escape(str.utf8_reverse)})/i.match(txt.utf8_reverse)

        if match
            backward_search(match[0].utf8_reverse, flags, limit)
        else
            nil
        end
    end

    def forward_case_insensitive_search(str, flags, limit=nil)
        unless limit
            limit = self.buffer.end_iter
        end

        txt = get_slice(limit)

        match = /(#{Regexp.escape(str)})/i.match(txt)

        if match
            forward_search(match[0], flags, limit)
        else
            nil
        end
    end
end