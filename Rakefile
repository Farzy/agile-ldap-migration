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
ROOTDN   = "cn=admin, o=idm, c=fr"
ROOTPW   = "Ur,ec1blC"

desc "Vérification de l'environnement d'exécution"
task :config do
  # Est-on sur la bonne machine
  if %x{hostname} != HOSTNAME
    raise RuntimeError, "ERREUR : La machine courante doit être '#{HOSTNAME}'"
  end
end

desc "Tâche par défaut : ne fait rien"
task :default => :config do
  puts "Veuillez lire la documentation avant de lancer ce programme"
end

desc "Récupération de l'annuaire 'isis' et nettoyage"
task :clean_ldif => :config do
	%x{ssh isis "slapcat" > #{INFILE}}
	%x{#{CLEANER} #{INFILE} > #{OUTFILE}}
end

desc "Test d'insertion des enregistrements LDAP sur #{HOSTNAME}"
task :test_ldif => :clean_ldif do
	%x{ldapadd -n -x -h localhost -D #{ROOTDN} -w #{ROOTPW} -f #{OUTFILE}}
end

# Attention : cette commande détruit le contenu de l'annuaire
desc "Insère de façon incrémentale les enregistrements LDAP sur #{HOSTNAME}"
task :insert_incr => :clean_ldif do
	%x{ldapadd -c -x -h localhost -D #{ROOTDN} -w #{ROOTPW} -f #{OUTFILE}}
end

# Attention : cette commande détruit le contenu de l'annuaire
desc "Détruit le contenu actuel de l'annuaire LDAP"
task :empty_directory => :config do
	%{/etc/init.d/slapd stop
	sleep 1
	rm -f /var/lib/ldap/*
	/etc/init.d/slapd start}
end

# Attention : cette commande détruit le contenu de l'annuaire
desc "Insère les enregistrements LDAP sur #{HOSTNAME} en détruisant le contenu précédent"
task :insert_full => [ :clean_ldif, :empty_directory] do
	%x{sleep 2
	ldapadd -c -x -h localhost -D #{ROOTDN} -w #{ROOTPW} -f #{OUTFILE}}
end

desc "Commande de duplication des dossiers Cyrus (sans leur contenu)"
task :create_mboxlist => :config do
		%x{ssh isis "su -c '/usr/sbin/ctl_mboxlist -d' cyrus" | \
		sed -n -e 's/idmfr_//g' -e '/^user\./ p' | \
		su -c '/usr/sbin/ctl_mboxlist -u' cyrus}
end
