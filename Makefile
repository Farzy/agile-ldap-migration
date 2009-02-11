INFILE	:= customer-orig.ldif
OUTFILE := customer-clean.ldif
CLEANER := ./customer-clean-ldif.rb
ROOTDN  := "cn=admin, o=customer, c=fr"
ROOTPW  := "Ur,ec1blC"

all:
	@echo "Vous devez specifier la commande a executer"
	exit 1

clean_ldif:
	ssh old-srv "slapcat" > $(INFILE)
	$(CLEANER) $(INFILE) > $(OUTFILE)

test_ldif: clean_ldif
	ldapadd -n -x -h localhost -D $(ROOTDN) -w $(ROOTPW) -f $(OUTFILE)

# Attention : cette commande détruit le contenu de l'annuaire
insert_incr: clean_ldif
	ldapadd -c -x -h localhost -D $(ROOTDN) -w $(ROOTPW) -f $(OUTFILE)

# Attention : cette commande détruit le contenu de l'annuaire
empty_directory:
	/etc/init.d/slapd stop
	sleep 1
	rm -f /var/lib/ldap/*
	/etc/init.d/slapd start

# Attention : cette commande détruit le contenu de l'annuaire
insert_full: clean_ldif empty_directory
	sleep 2
	ldapadd -c -x -h localhost -D $(ROOTDN) -w $(ROOTPW) -f $(OUTFILE)

# Commande de duplication des dossiers Cyrus (sans leur contenu)
create_mboxlist:
		ssh old-srv "su -c '/usr/sbin/ctl_mboxlist -d' cyrus" | \
		sed -n -e 's/customerfr_//g' -e '/^user\./ p' | \
		su -c '/usr/sbin/ctl_mboxlist -u' cyrus
