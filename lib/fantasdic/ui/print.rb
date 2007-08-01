# Fantasdic
# Copyright (C) 2007 Mathieu Blondel
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

class Pango::Layout
    def size_in_points
        self.size.collect { |v| v / Pango::SCALE }
    end

    def width_in_points
        self.size[0] / Pango::SCALE
    end

    def height_in_points
        self.size[1] / Pango::SCALE
    end

    def width_in_points=(width)
        self.width = width * Pango::SCALE
    end
end

module Fantasdic
module UI

class Print < Gtk::PrintOperation

    include GetText
    GetText.bindtextdomain(Fantasdic::TEXTDOMAIN, nil, nil, "UTF-8")

    FONT = Pango::FontDescription.new("sans 10")
    FONT_SMALL = Pango::FontDescription.new("sans 8")
    FONT_BIG = Pango::FontDescription.new("sans 12")
    FONT_BIG.weight = Pango::FontDescription::WEIGHT_BOLD

    FONT_SIZE, FONT_SMALL_SIZE, FONT_BIG_SIZE = \
    [FONT, FONT_SMALL, FONT_BIG].collect do |f|
        f.size / Pango::SCALE
    end

    def initialize (parent_window, title, definitions)
        super()
        @parent_window = parent_window

        @title = title
        @definitions = definitions

        # with this option disabled, (0,0) is the the upper left corner
        # taking into account margins !
        self.use_full_page = false
        self.unit = Gtk::PaperSize::UNIT_POINTS

        # set default paper size
        page_setup = Gtk::PageSetup.new
        paper_size = Gtk::PaperSize.new(Gtk::PaperSize.default)
        page_setup.paper_size_and_default_margins = paper_size
        self.default_page_setup = page_setup

        # show a progress bar
        self.show_progress = true        

        signal_connect("begin-print") do |pop, context|
            pop.n_pages = calculate_n_pages(pop, context)            
        end

        signal_connect("draw-page") do |pop, context, page_num|
            draw_page(pop, context, page_num)
        end        
    end

    def run_print_dialog
        res = run(ACTION_PRINT_DIALOG, @parent_window)
#         case res
#             when RESULT_ERROR
#                 puts "error"
#             when RESULT_CANCEL
#                 puts "cancelled"
#             when RESULT_APPLY
#                 puts "applied"
#             when RESULT_IN_PROGRESS
#                 puts "in progress"            
#         end
    end

    def run_preview
        res = run(ACTION_PREVIEW, @parent_window)
    end

    private

    def create_layout(cr, font_desc, text)
        layout = cr.create_pango_layout

        layout.width_in_points = page_width
        layout.font_description = font_desc
        layout.wrap = Pango::Layout::WRAP_CHAR
        layout.ellipsize = Pango::Layout::ELLIPSIZE_NONE
        layout.single_paragraph_mode = false

        layout.text = text

        layout
    end

    def split_into_paragraphe_layouts(cr, definitions)
        layouts = []

        last_db = nil
        @definitions.each do |d|
            if d.database != last_db
                layouts << create_layout(cr, FONT_BIG, "%s\n" % [d.description])
                last_db = d.database
            end
            d.body.split("\n").each do |para|
                layouts << create_layout(cr, FONT, para.strip)
            end
        end

        layouts
    end

    def page_height
        setup = self.default_page_setup
        # this takes margins into consideration
        setup.get_page_height(Gtk::PaperSize::UNIT_POINTS)
    end

    def real_page_height
        page_height - header_height - footer_height
    end

    def page_width
        setup = self.default_page_setup
        width = setup.get_page_width(Gtk::PaperSize::UNIT_POINTS)
    end

    def calculate_n_pages(pop, context)
        cr = context.cairo_context
        paragraphe_layouts = split_into_paragraphe_layouts(cr, @definitions)

        @page_layouts = []

        curr_height = 0
        n_pages = 0
        paragraphe_layouts.each do |layout|
            height = layout.height_in_points
            if curr_height + height > real_page_height
                n_pages += 1
                curr_height = 0
            end
            @page_layouts[n_pages] ||= []
            @page_layouts[n_pages] << layout
            curr_height += height
        end

        n_pages + 1
    end

    def header_height
        4 * FONT_SMALL_SIZE
    end

    def footer_height
        4 * FONT_SMALL_SIZE
    end

    def draw_header(cr, nth_page, total_page)
        layout = cr.create_pango_layout
        layout.alignment = Pango::Layout::ALIGN_RIGHT
        layout.font_description = FONT_SMALL
        layout.text = _("Definitions for %s") % @title + " - " + \
                      _("Page %d/%d") % [nth_page, total_page]
        width, height = layout.size_in_points
        cr.move_to(page_width - width, height)
        cr.show_pango_layout(layout)
    end

    def draw_footer(cr)        
        layout = cr.create_pango_layout
        layout.alignment = Pango::Layout::ALIGN_RIGHT
        layout.font_description = FONT_SMALL
        layout.text = \
            Time.now.strftime(_("Printed by Fantasdic on %Y/%m/%d at %H:%M")) +
                "\n" + Fantasdic::WEBSITE_URL
        width, height = layout.size_in_points
        x, y = [page_width, page_height]
        x -= width
        y -= height
        cr.move_to(x, y)
        cr.show_pango_layout(layout)
        cr.rel_move_to(width, -2)
        cr.rel_line_to(-page_width, 0)
        cr.stroke
    end

    def draw_page(pop, context, page_num)
        cr = context.cairo_context

        x = 0
        y = header_height

        # page_num starts at 0
        draw_header(cr, page_num + 1, @page_layouts.length)

        @page_layouts[page_num].each do |layout|
            cr.move_to(x,y)
            cr.show_pango_layout(layout)            
            y += layout.height_in_points
        end
        
        draw_footer(cr)
    end

end

end
end