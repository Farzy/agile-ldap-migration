#!/usr/bin/env ruby
# -*- coding: UTF-8 -*-
# vim: sw=2 sts=2:

# smtp-simulator : Client SMTP pour des tests d'envoi/réception
# de mails en local

# Auteur:: Farzad FARID
# Copyright:: (C) 2009 Pragmatic Source
#
# = Licence
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# = Synopsys
#
# Ce programme dialogue directement avec le port 25 de la machine locale
# pour envoyer un mail à Postfix.

require 'net/smtp'

# Création du mail à envoyer
user_from = "ffarid@pragmatic-source.com" # Compte externe
user_to = "enqueteirfdev@idm.fr" # Compte de test IDM
the_email = <<EOT
From: #{user_from}
To: #{user_to}
Subject: Test migration messagerie, mail pour #{user_to}

Email de test.
EOT

puts "Envoi en local d'un mail de #{user_from} vers #{user_to}.."
# handling exceptions
begin
 Net::SMTP.start('localhost', 25) do |smtpclient|
   smtpclient.send_message(the_email, user_from, user_to)
 end
 puts "Mail envoyé"
rescue Exception => e
 print "Exception occured: " + e
end