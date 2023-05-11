use strict;
use warnings;
use FindBin;
use Data::UUID;
use Mojolicious::Lite;
use Mojo::Server::Daemon;

use JSON;
my $path = $FindBin::Bin;
use lib "./lib";
use TestAppDB;

#use Data::Dumper;

my $config = getConfig();

my $dbh = TestAppDB->new( $config->{nameDB}, $config->{hostDB}, $config->{userDB}, $config->{userPasswordDB} );
if ( !$dbh ) {
    die("Init DB fail!");
}
else {
    print "Init DB success! \n";
}

print "Start App! \n";

$dbh->checkDbSchema( $config->{nameDB} );

# Проверяем наличие папки upload
sub createUploaDir {
    my ($path) = @_;
    my $uploadDir = $path . "/upload";
    unless ( -d $uploadDir ) {
        if ( mkdir $uploadDir ) {
            return 0;
        }
        else {
            return 0;
        }

    }
}

#Имя фала в формате UUID
sub getNewFileName {
    my $ug = Data::UUID->new;
    return $ug->create_str() . ".log";
}

#Обработчик загрузки файла
post '/api/upload-log-file' => sub {
    my $c      = shift;
    my $upload = $c->req->upload('files');

    #Возвращаем 400, если не получилось загрузить
    return $c->render( status => 400, message => 'File not found' ) unless $upload;

    unless ( createUploaDir($path) ) {
        $c->render( status => 400, message => 'Error create upload dir' );
    }

    my $newFileName = getNewFileName();
    my $filePath    = $path . "/upload/" . $newFileName;

    # Сохраняем файл на диск
    $upload->move_to($filePath);

    # парсим фаил
    parseUploadFile($filePath);

    #парсим фаил
    $c->render( json => { message => 'File upload success!', newFileName => $newFileName, oldFileName => $upload->filename } );
};

#Обработчик поиск
post '/api/search-email-log' => sub {
    my $c    = shift;
    my $json = $c->req->json;

    # Дальнейшая обработка JSON
    my $query = "

   WITH  emails_id as (select int_id from log where address = ? group by int_id)
          select *
           from (
            select l.created, l.str, l.int_id, l.address
            from emails_id a
             inner join log l on l.int_id = a.int_id
             union all
             select  m.created, m.str, m.int_id, null as address
             from emails_id a1
             inner join message m on  m.int_id = a1.int_id
         ) t order by created desc
        limit 101
     ";

    my @IdEmails = $dbh->getData( $query, $json->{email} );

    my $limit = 0;

    $limit = 1 if scalar( $IdEmails[1]->@* ) > 100;
    my @response = ( limit => $limit, @IdEmails );

    # my $email_list = join(',', map { $dbh->quoteTool($_->{int_id}) } @IdEmails);
    # my $query2 = "select * from log where int_id in ($email_list)";
    $c->render( json => {@response} );
};

#     <= прибытие сообщения (в этом случае за флагом следует адрес отправителя)
#     => нормальная доставка сообщения
#     -> дополнительный адрес в той же доставке
#     ** доставка не удалась
#     == доставка задержана (временная проблема)

#В таблицу message должны попасть только строки прибытия сообщения (с флагом <=).
#В таблицу log записываются все остальные строки:
sub parseUploadFile {
    my ($filePath) = @_;

    #Очистим таблицы. для повторной загрузки т.к. есть PRIMARY KEY
    $dbh->clearDb();

    open( my $file, '<', $filePath ) or die "Не удалось открыть файл: $!";
    while ( my $line = <$file> ) {

        my $date       = '';
        my $time       = '';
        my $flag       = '';
        my $message_id = '';
        my $address    = '';
        my $id         = '';
        my $str        = '';

        #<= прибытие сообщения (в этом случае за флагом следует адрес отправителя)
        #разбираем строку регулярным вырожением, гггг-мм-дд чч:мм флаг внутренний ид сообщения емаил  ид сообщения
        # my @arr = split('\s', $line);
        if ( $line =~ /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(<=)\s+(\S+@\S+).+?\s+id=(\S+)/ ) {
            $date       = $1;
            $time       = $2;
            $flag       = $4;
            $message_id = $3;
            $address    = $5;
            $id         = $6;
            $str        = '';

            #str - строка лога (без временной метки).
            if ( $line =~ /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(<=)\s+(.*)/ ) {
                $str = $5;
            }
            else {
                $str = "Неверное регулярное вырожение.";
            }

            my $query         = "INSERT INTO message (created,id, int_id,str,status) values (?,?,?,?,?)";
            my $rows_affected = $dbh->insertData( $query, $date . " " . $time, $id, $message_id, $str, 1 );
        }
        else {
            #получим записи где есть флаг, email
            if ( $line =~ /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(=>|->|\*\*|==)\s+(\S+@\S+)\s+(.*)/ ) {
                $date       = $1;
                $time       = $2;
                $message_id = $3;
                $flag       = $4;
                $address    = $5;
                $str        = $6;

                $address =~ s/:.*//;

                # print $address;

                my $query         = "INSERT INTO log (created, int_id,str,address) values (?,?,?,?)";
                my $rows_affected = $dbh->insertData( $query, $date . " " . $time, $message_id, $str, $address );
            }
            elsif ( $line =~ /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(.*)/ ) {

                #все остальные строки
                $date       = $1;
                $time       = $2;
                $message_id = $3;
                $str        = $4;

                # print $date." ".$time." ".$message_id." ".$str."\n";
                my $query         = "INSERT INTO log (created, int_id,str) values (?,?,?)";
                my $rows_affected = $dbh->insertData( $query, $date . " " . $time, $message_id, $str );
            }
        }
    }
    close($file);
}

#Читаем конфиг
sub getConfig {
    my ($self) = @_;

    my $json_text = do {
        open( my $json_fh, "<:encoding(UTF-8)", "config.json" )
            or die("Не удалось открыть фаил config.json: $!\n");
        local $/;    #устанавливает временно значение переменной в undef. чтобы считать целиком
        <$json_fh>;
    };

    my $json = JSON->new;

    return $json->decode($json_text);
}

#Разрешим cross запросы
app->hook(
    after_dispatch => sub {
        my $c = shift;
        $c->res->headers->header( 'Access-Control-Allow-Origin' => '*' );
        $c->res->headers->access_control_allow_origin('*');
        $c->res->headers->header( 'Access-Control-Allow-Methods' => 'GET, OPTIONS, POST, DELETE, PUT' );
        $c->res->headers->header( 'Access-Control-Allow-Headers' => 'Content-Type' => 'Content-Type' );
    }
);

#Дли всех OPTIONS запросов вернем 200
app->hook(
    after_dispatch => sub {
        my $c = shift;
        if ( $c->req->method eq 'OPTIONS' ) {
            $c->res->code(200);
        }
    }
);

my $default_index = 'index.html';


app->hook(
    before_dispatch => sub {
        my $c = shift;
      
        my $url_path = $c->req->url;
        my $path = "$url_path";
        if( -d $path ) {
            $url_path .= '/' unless $path =~ m|/\z|;
            $url_path .= $default_index;
            $c->req->url->path( $url_path );
        }
    }
);

my $static = app->static;

push @{ $static->paths }, $path . "/public";
push @{ $static->paths }, $path . "/public/assets";

# Запуск приложения
my $daemon = Mojo::Server::Daemon->new(
    app    => app,
    listen => [ "http://*:" . $config->{serverPort} ]
);
$daemon->run;
