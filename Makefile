INFILE	:= idm-orig-20081128.ldif
OUTFILE := idm-clean.ldif
CLEANER := ./idm-clean-ldif.rb
ROOTDN  := "cn=admin, o=idm, c=fr"
ROOTPW  := "Ur,ec1blC"

all:
	@echo "Vous devez specifier la commande a executer"
	exit 1

clean_ldif:
	$(CLEANER) $(INFILE) > $(OUTFILE)

test: clean_ldif
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
