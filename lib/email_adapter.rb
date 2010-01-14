# Copyright (C) 2010 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

require 'net/smtp'

# Adapts an email subsystem to polisher
class EmailAdapter
   # send email w/ specified args
   def self.send_email(args = {})
      server   = args[:server]
      to       = args[:to]
      from     = args[:from]
      body     = args[:body]
      subject  = args[:subject]
      logger   = args[:logger]
       
      logger.info ">> sending email to #{to} from #{from} using smtp server #{server}" unless logger.nil?
      msg = <<END_OF_MESSAGE
From: #{from}
To: #{to}
Subject: #{subject}

#{body}
END_OF_MESSAGE
    
    Net::SMTP.start(server) do |smtp|
        smtp.send_message msg, from, to
    end
   end

end
