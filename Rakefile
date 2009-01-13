# 
# Rakefile de contrôle de la migration LDAP / IMAP d'IDM
# 
# Date : 2009-01-13
# 
# Copyright (C) 2009 Farzad FARID <ffarid@pragmatic-source.com>
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


require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

#######################################################################
# Configuration
#######################################################################
HOSTNAME = "berumail"
TESTDIR  = File.join(File.dirname(__FILE__), "test")
INFILE	 = File.join(TESTDIR, "idm-orig.ldif")
OUTFILE  = File.join(TESTDIR, "idm-clean.ldif")
CLEANER  = File.join("lib", "idm-clean-ldif.rb")
SMTP_SIMULATOR = File.join("lib", "smtp-simulator.rb")
ROOTDN   = "cn=admin, o=idm, c=fr"
ROOTPW   = "Ur,ec1blC"

# Affiche une chaîne, pour exécute là dans un shell
def puts_and_exec(str)
  puts ">>> " + str
  puts %x{#{str}}
end

desc "Vérification de l'environnement d'exécution"
task :config do
  # Est-on sur la bonne machine
  if %x{hostname}.strip != HOSTNAME
    raise RuntimeError, "ERREUR : La machine courante doit être '#{HOSTNAME}'"
  end
end

desc "Tâche par défaut : ne fait rien"
task :default => :config do
  puts "Veuillez lire la documentation avant de lancer ce programme"
end

namespace :ldap do
  desc "Récupération de l'annuaire 'isis' et nettoyage"
  task :clean_ldif => :config do
    puts "Récupération de l'annuaire LDAP d'isis"
    puts_and_exec %{ssh isis "slapcat" > "#{INFILE}"}
    puts "Nettoyage de l'annuaire LDAP"
    puts_and_exec %{#{CLEANER} "#{INFILE}" > "#{OUTFILE}"}
  end

  desc "Test d'insertion des enregistrements LDAP sur #{HOSTNAME}"
  task :test_ldif => :clean_ldif do
    puts "Simulation d'insertion des enregistrements LDAP"
    puts_and_exec %{ldapadd -n -x -h localhost -D "#{ROOTDN}" -w "#{ROOTPW}" -f "#{OUTFILE}"}
  end

  # Attention : cette commande détruit le contenu de l'annuaire
  desc "Insère de façon incrémentale les enregistrements LDAP sur #{HOSTNAME}"
  task :insert_incr => :clean_ldif do
    puts "Insertion incrémentable des enregistrements LDAP"
    puts_and_exec %{ldapadd -c -x -h localhost -D "#{ROOTDN}" -w "#{ROOTPW}" -f "#{OUTFILE}"}
  end

  # Attention : cette commande détruit le contenu de l'annuaire
  desc "Détruit le contenu actuel de l'annuaire LDAP"
  task :empty_directory => :config do
    puts "Remise à zéro de l'annuaire LDAP"
    puts_and_exec %{/etc/init.d/slapd stop
    sleep 1
    rm -f /var/lib/ldap/*
    /etc/init.d/slapd start}
  end

  # Attention : cette commande détruit le contenu de l'annuaire
  desc "Insère les enregistrements LDAP sur #{HOSTNAME} en détruisant le contenu précédent"
  task :insert_full => [ :clean_ldif, :empty_directory] do
    puts "Insertion complète des enregistrements LDAP"
    puts_and_exec %{sleep 2
    ldapadd -c -x -h localhost -D "#{ROOTDN}" -w "#{ROOTPW}" -f "#{OUTFILE}"}
  end
end

namespace :imap do
  desc "Commande de duplication des dossiers Cyrus (sans leur contenu)"
  task :create_mboxlist => :config do
    puts "Duplication des dossiers Cyrus Imap"
    puts_and_exec %{ssh isis "su -c '/usr/sbin/ctl_mboxlist -d' cyrus" | \
      sed -n -e 's/idmfr_//g' -e '/^user\\./ p' | \
      su -c '/usr/sbin/ctl_mboxlist -u' cyrus}
  end
end
  
namespace :smtp do
  desc "Envoie un mail de test en local au serveur SMTP"
  task :test_local => :config do
    puts "Test d'envoi d'un mail en local à une adresse @idm.fr de test"
    puts_and_exec SMTP_SIMULATOR
  end
end
