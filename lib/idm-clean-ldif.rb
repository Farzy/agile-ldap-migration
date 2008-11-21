#!/usr/bin/env ruby
# -*- coding: None -*-
# vim: sw=2 sts=2:

# idm-clean-ldif.rb : Nettoyage et mise en confirmité de l'annuaire
# LDAP IDM pour OpenLDAP 2.3

# Auteur:: Farzad FARID
# Copyright:: (C) 2008 Pragmatic Source
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
# Ce programme prend en entrée un fichier LDIF au format OpenLDAP 2.0,
# avec les objets dans le désordres et des attributs manquants, et ressort
# un fichier LDIF correct.

# Passage en UTF-8
$KCODE = 'u'
require 'jcode'

require 'rubygems'
require 'ldap'
require 'ldap/ldif'
require 'trollop'
require 'pp'

PROGNAME = "idm-clean-ldif"
VERS = "1.0"

class LdapCleaner
  attr_accessor :infile, :ldif

	# Trouve le RDN dans un DN bien formé
	RDN_REG = /^(.*?)=(.*?),.*$/

  # Ces fonctions sont inspirées de LDAP::LDIF

  LINE_LENGTH = 77

  # return *true* if +str+ contains a character with an ASCII value > 127 or
  # a NUL, LF or CR. Otherwise, *false* is returned.
  #
  def self.unsafe_char?( str )
    # This could be written as a single regex, but this is faster.
    str =~ /^[ :]/ || str =~ /[\x00-\x1f\x7f-\xff]/
  end

  # Perform Base64 decoding of +str+. If +concat+ is *true*, LF characters
  # are stripped.
  #
  def self.base64_encode( str, concat=false )
    str = [ str ].pack( 'm' )
    str.gsub!( /\n/, '' ) if concat
    str
  end

  # Convert an attribute to LDIF
  # 
  # * attr: attribute name
  # * vals: a hash of values
  def self.attr_to_ldif(attr, vals)
    ldif_string = ''

    vals.each do |val|
      val = val.clone # Essentiel
      sep = ':'
      if unsafe_char?( val )
        sep = '::'
        val = base64_encode( val, true )
      end

      firstline_len = LINE_LENGTH - ( "%s%s " % [ attr, sep ] ).length
      ldif_string << "%s%s %s\n" % [ attr, sep, val.slice!( 0..firstline_len ) ]

      while val.length > 0
        ldif_string << " %s\n" % val.slice!( 0..LINE_LENGTH - 1 )
      end
    end

    ldif_string
  end

  # Convert an LDAP::Record to LDIF.
  # Cleanup Schema errors.
  def self.to_ldif(ldap_record)
    # Certains DN contiennent un retour chariot, à corriger
    dn = ldap_record.dn.gsub(/\n/, '')
    attrs = ldap_record.attrs

    ldif_string = "dn: %s\n" % dn

    # Le CN présent dans les attributs est parfois erroné, et
    # différent du RDN. Autant forcer sa valeur avant insertion
    md = RDN_REG.match(dn)
    rdn_name  = md[1]
    rdn_value = md[2]
    attrs[rdn_name] = rdn_value

    # Entrée de test à supprimer, car elle est incorrecte
    return if dn == "cn=test,o=idm,c=fr"
    
    # Entrées de type societyUnit (su), enregistrée avec l'OC
    # "ou" par erreur. On force l'attribut, au cas où il
    # n'existe pas
    # On doit en plus tenir compte de plusieurs casses pour "societyUnit"
    if rdn_name == "su" # and !( attrs["objectclass"].include?("societyUnit") || attrs["objectclass"].include?("SocietyUnit"))
      attrs["objectclass"] -= [ "societyUnit", "SocietyUnit", "organizationalUnit" ]
      attrs["objectclass"] << "societyUnit"
    end

    # su=glucoz.com contient un attribut "ou" qu'il faut supprimer
    # "gensduvoyage.com" aussi
    if (rdn_name == "su" && rdn_value == "glucoz.com") || dn == "su=gensduvoyage.com, o=idm, c=fr"
      attrs.delete("ou")
    end
    
    # Pour certains RDN "ou=", l'object class organizationalUnit correspondant
    # est manquant
    if rdn_name == "ou" && !attrs["objectclass"].include?("organizationalUnit")
      attrs["objectclass"] << "organizationalUnit"
    end
    
    # Les enregistrements qui ne contiennent que l'OC "mailRecipient" en dehors de
    # "top" servent à du mail forwarding. Comme cet OC n'est pas STRUCTURAL, on le 
    # remplace par le nouvel OC "mailForwarder", qui l'est.
    if attrs["objectclass"].sort == [ "mailRecipient", "top" ]
      attrs["objectclass"] = [ "top", "mailForwarder" ]
    end
    
    # L'attribut "intragroup" nécessite soit l'OC "projectUser", soit "baseContact"
    # On rajoute le premier OC si aucun des 2 n'est présent
    if attrs.has_key?("intragroup") && (attrs["objectclass"] & [ "projectUser", "baseContact"]).empty?
      attrs["objectclass"] << "projectUser"
    end

    # On ne peut pas avoir à la fois les OC "organizationalPerson" et
    # "organizationalRole"
    # XXX : le nom des 2 OC est parfois en minuscule dans ce cas d'erreur
    if !(attrs["objectclass"] & [ "organizationalperson", "organizationalrole" ]).empty? ||
        !(attrs["objectclass"] & [ "organizationalPerson", "organizationalRole" ]).empty?
      # on enlève "organizationalPerson" si l'attribut "sn" n'existe pas
      if attrs.has_key?("sn")
        attrs["objectclass"] -= [ "organizationalrole" ]
        attrs["objectclass"] -= [ "organizationalRole" ]
      else
        attrs["objectclass"] -= [ "organizationalperson" ]
        attrs["objectclass"] -= [ "organizationalPerson" ]
      end
    end

    # Doublon d'OC
    if !(attrs["objectclass"] & [ "organizationalperson", "organizationalPerson" ]).empty?
      attrs["objectclass"] -= [ "organizationalperson" ]
    end
    if !(attrs["objectclass"] & [ "projectuser", "projectUser" ]).empty?
      attrs["objectclass"] -= [ "projectuser" ]
    end


    # L'OC "cvsuser" n'est pas structurel
    if (attrs["objectclass"].include?("cvsuser") || attrs["objectclass"].include?("cvsUser")) &&
        (attrs["objectclass"] & [ "person", "organizational", "inetOrgPerson" ]).empty?
      attrs["objectclass"] << "inetOrgPerson"
    end
    
    # L'OC "baseContact" doit au minimum avoir aussi "organizationalPerson"
    if (attrs["objectclass"].sort == [ "baseContact", "top" ]) ||
        (attrs["objectclass"].sort == [ "baseContact", "projectUser", "top" ])
      attrs["objectclass"] << "organizationalPerson"
    end
    
    # Les attributs "st" et "postaladdresss" nécessitent l'OC "organizationalPerson"
    if (attrs.has_key?("st") || attrs.has_key?("postaladdress")) and !attrs["objectclass"].include?("organizationalPerson")
      attrs["objectclass"] << "organizationalPerson"     
    end
    
    attrs.each do |attr,vals|
      ldif_string << attr_to_ldif(attr, vals)
    end

    ldif_string
    #LDIF::Entry.new( ldif )
  end

  #--------------------

  def initialize
  end

  def parse_arguments
    opts = Trollop::options do
      version "#{PROGNAME} #{VERS} (c) 2008 Farzad FARID"
      banner <<-EOS
Convertit un fichier LDAP au format LDIF d'un version ancienne et buggée
d'OpenLDAP en un fichier LDIF compatible avec OpenLDAP 2.3.

Usage: #{PROGNAME} [options] <Fichier LDIF>
EOS
      opt :debug, "Mode debug", :default => false
    end

    if ARGV.size != 1 || !File.exist?(ARGV[0])
      Trollop::die "Fichier LDIF manquant ou trop de paramètres"
    end
    self.infile = ARGV[0]
  end

  def read_ldif(filename = nil)
    self.infile ||= filename
    # Lecture du fichier LDIF et tri des enregistrements
    self.ldif = LDAP::LDIF::parse_file(infile, true)
    # Les données peut être volumineuses, on ne veut pas que ça
    # puisse s'afficher en cas d'utilisation de ce script sous "irb"..
    nil
  end

  def clean_ldif
    output = ''

    ldif.each { |rec|
      # On enlève les attributs système
      rec.clean
      # Cette fonction fait un gros nettoyage
      obj = LdapCleaner::to_ldif(rec)
      output << obj << "\n" if !obj.nil?
    }
    output
  end

  def run
    parse_arguments
    read_ldif
    data = clean_ldif
    puts data
  end

end

if __FILE__ == $0
  app = LdapCleaner.new
  app.run
end
