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

# Note : les tâches Rake qui n'ont pas besoin d'être visibles pour
# l'utilisateur n'ont pas de description "desc".

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

#######################################################################
# Configuration
#######################################################################
TESTDIR  = File.join(File.dirname(__FILE__), "test")
DATADIR  = File.join(File.dirname(__FILE__), "data")
CLEANER  = File.join("lib", "idm-clean-ldif.rb")
SMTP_SIMULATOR = File.join("lib", "smtp-simulator.rb")

MyConfig = YAML.load(IO.read(File.join(File.dirname(__FILE__), "config.yml")))
HOSTNAME = MyConfig["hostname"]
ROOTDN   = MyConfig["ldap"]["user"]
ROOTPW   = MyConfig["ldap"]["password"]
INFILE	 = File.join(DATADIR, MyConfig["ldap"]["infile"])
OUTFILE  = File.join(DATADIR, MyConfig["ldap"]["outfile"])


# Affiche une chaîne, pour exécute là dans un shell
def puts_and_exec(str)
  puts ">>> " + str
  puts %x{#{str}}
end

# Vérification de l'environnement d'exécution
task :config do
  # Est-on sur la bonne machine ?
  if %x{hostname}.strip != HOSTNAME
    raise RuntimeError, "ERREUR : La machine courante doit être '#{HOSTNAME}'"
  end
  # Est-on root ?
  if Process.uid != 0
    raise RuntimeError, "ERREUR : Le script doit tourner sous l'utilisateur root'"
  end
end

# Tâche par défaut : ne fait rien
task :default do
  puts "Veuillez consulter 'rake -T' ou la documentation avant de lancer ce programme"
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
  task :insert_test => :clean_ldif do
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
  # Connexion au serveur IMAP local
  task :connect => :config do
    require 'net/imap'

    IMAP = Net::IMAP.new("localhost")
    IMAP.login(MyConfig["imap"]["user"], MyConfig["imap"]["password"])
    # Extension de la class d'IMAP pour ajouter une fonction de logging
    # Si la fonction appelée est "IMAP.show_*" alors on affiche
    # la commande réelle et ses paramètre, et ensuite on exécute la
    # commande dans le contexte IMAP.
    class << IMAP
      def method_missing(method, *arguments)
        # Si la fonction appelée est "show_*" alors affiche
        # la commande "*" et ensuite exécute la dans le contexte IMAP
        if method.to_s =~ /^show_(\w+)$/
          imapcmd = $1
          puts ">> IMAP #{imapcmd}#{arguments.inspect}"
          self.send(imapcmd, *arguments)
        else
          super
        end
      end
    end
  end
  
  # Récupère la liste les dossiers Cyrus importables depuis isis
  task :get_mboxlist => :config do
    MBOXLIST = %x{ssh isis "su -c '/usr/sbin/ctl_mboxlist -d' cyrus" | \
      sed -n -e 's/idmfr_//g' -e '/^user\\./ p' }
  end

  desc "Liste les dossiers Cyrus importables depuis isis"
  task :show_mboxlist => :get_mboxlist do
    puts "Liste des dossiers Cyrus Imap importables d'isis"
    puts MBOXLIST
  end

  desc "Commande de duplication des dossiers Cyrus (sans leur contenu)"
  task :create_mboxlist => :config do
    puts "Duplication des dossiers Cyrus Imap"
    puts_and_exec %{ssh isis "su -c '/usr/sbin/ctl_mboxlist -d' cyrus" | \
      sed -n -e 's/idmfr_//g' -e '/^user\\./ p' | \
      su -c '/usr/sbin/ctl_mboxlist -u' cyrus}
  end

  desc "Envoie des commandes de test à Cyrus Imap"
  task :test => "imap:connect" do
    puts "Test du serveur IMAP"
    puts "Capability after login: #{IMAP.capability.join(' ')}"
    puts "Création d'un compte/dossier IMAP"
    IMAP.show_create("user.ffarid")
    puts "Anciens droits du dossier :"
    IMAP.show_getacl("user.ffarid").each do |right|
      puts "  #{right.user} : #{right.rights}"
    end
    puts "Tentative de création d'un dossier qui existe déjà"
    begin
      IMAP.show_create("user.ffarid")
    rescue Net::IMAP::NoResponseError => e
      puts ">>>> Exception #{e}"
    end
    puts "Modification des ACL"
    IMAP.show_setacl("user.ffarid", "cyrus", "lrswipcda")
    puts "Nouveaux droits du dossier :"
    IMAP.show_getacl("user.ffarid").each do |right|
      puts "  #{right.user} : #{right.rights}"
    end
    IMAP.show_delete("user.ffarid")
  end

  desc "Création de tous les dossiers IMAP"
  task :create_folders => [ "imap:connect", "imap:get_mboxlist" ] do
    puts "Création de tous les dossiers IMAP"
    # Extraction de la liste des dossiers de MBOXLIST : on garde
    # le 1er champ de chaque ligne
    folders = MBOXLIST.split(/\n/).map { |l| l.split(/\t/).first }
    folders.each do |folder|
      puts "Création de #{folder}"
      begin
        IMAP.show_create(folder)
      rescue Net::IMAP::NoResponseError => e
        puts ">>>> Exception #{e}"
      end
      IMAP.show_setacl(folder, "cyrus", "lrswipcda")
    end
  end
end
  
namespace :smtp do
  desc "Envoie un mail de test en local au serveur SMTP"
  task :test_local => :config do
    puts "Test d'envoi d'un mail en local à une adresse @idm.fr de test"
    puts_and_exec SMTP_SIMULATOR
  end
end
