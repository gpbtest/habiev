use strict;
use warnings;

package TestAppDB;

use DBI;
our $dbh;

#use Data::Dumper;

my @tablesToDb = (
    {
        name => 'message',
        sql  => '
        CREATE TABLE `message` (
        `created` TIMESTAMP  NOT NULL,
         `id` CHAR(250) NOT NULL,
         `int_id` CHAR(250) NOT NULL,
         `str` VARCHAR(2000) NOT NULL,
         `status` TINYINT(1) NOT NULL ,
        CONSTRAINT `message_id_pk` PRIMARY KEY(id));
        '
    },
    {
        name => 'log',
        sql  => 'CREATE TABLE `log` (
        `created`  TIMESTAMP  NOT NULL,
        `int_id` CHAR(16) NOT NULL,
        `str` VARCHAR(2000),
        `address` VARCHAR(2000)
        )'
    },
    {
        name => 'upload_files',
        sql  => 'CREATE TABLE `upload_files` (
            `created`  TIMESTAMP  NOT NULL,
            `file_old_name` VARCHAR(500) NOT NULL,
            `file_new_name` VARCHAR(2000)
            )'
    },
);

#Инициализируем таблицы  БД
sub initTables {
    my (@tablesInDb) = @_;

    foreach my $tableHash (@tablesToDb) {
        unless ( checkTableInArray( $tableHash->{name}, @tablesInDb ) ) {
            my $sth = $dbh->prepare( $tableHash->{sql} );
            $sth->execute();
            print "Create table " . $tableHash->{name} . "\n";
        }
    }
}

#Проверяем наличие таблицы
sub checkTableInArray {
    my ( $tableName, @tablesArray ) = @_;
    if ( grep { $_ eq $tableName } @tablesArray ) {
        return 1;
    }
    else {
        return 0;
    }
}

#Инициализируем подключение к БД
sub new {
    my ( $class, $nameDB, $hostDB, $userDB, $passwordDB, $config ) = @_;

    $dbh = DBI->connect( "DBI:mysql:database=$nameDB;host=$hostDB", "$userDB", "$passwordDB" )
        or die "Could not connect to database: " . DBI->errstr;
    my $self = { _dbh => $dbh };

    bless $self, $class;
    return $self;
}

#Функция проверки схемы БД
sub checkDbSchema {
    my ( $self, $dbh, $config ) = @_;

    #получим все таблицы схемы
    my $sth = $self->{_dbh}->prepare("SHOW TABLES");
    $sth->execute();

    my @tablesInDb = ();
    while ( my @row = $sth->fetchrow_array() ) {
        push @tablesInDb, $row[0];
    }

    #инициалицируем таблицы
    initTables(@tablesInDb);
}

#получения данных
sub getData {
    my ( $self, $query, @params ) = @_;

    my $sth = $self->{_dbh}->prepare($query);
    $sth->execute(@params);

    my @data;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @data, $row;
    }
    my @result = ( data => \@data, count => $sth->rows );
    return @result;
}

#получения данных
sub getRawData {
    my ( $self, $query, @params ) = @_;

    my $sth = $self->{_dbh}->prepare($query);
    $sth->execute(@params);

    return $sth->fetchrow_hashref();
}

#Вставка записи
sub insertData {
    my ( $self, $query, @params ) = @_;

    my $sth = $self->{_dbh}->prepare($query)
        or die "Error prepare sql: " . $self->{_dbh}->errstr;

    $sth->execute(@params)
        or die "Error execute sql: " . $sth->errstr;

    my $rows_affected = $sth->rows;

    return $rows_affected;
}

sub clearDb {
    my ($self) = @_;

    foreach my $tableHash (@tablesToDb) {
        my $query = "delete from " . $tableHash->{name};
        my $sth   = $dbh->prepare($query);
        $sth->execute();
    }
}

sub quoteTool {
    my ( $self, $value ) = @_;
    return $dbh->quote($value);
}

1;
