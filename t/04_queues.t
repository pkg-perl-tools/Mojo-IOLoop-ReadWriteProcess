#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

use Mojo::IOLoop::ReadWriteProcess qw(queue process);
use Mojo::IOLoop::ReadWriteProcess::Session;

subtest queues => sub {
  my $q = queue;
  $q->pool->maximum_processes(3);
  $q->queue->maximum_processes(800);

  my $proc = 10;
  my $fired;

  my $i = 1;
  for (1 .. $proc) {
    $q->add(process(sub { shift; return shift() })->args($i));
    $i++;
  }

  my %output;
  $q->once(
    stop => sub {
      $fired++;
      $output{shift->return_status}++;
    });
  is $q->queue->size,             $proc - $q->pool->maximum_processes;
  is $q->pool->size,              3;
  is $q->pool->maximum_processes, 3;
  $q->consume;
  is $fired, $proc;
  is $q->queue->size, 0;
  is $q->pool->size,  0;

  $i = 1;
  for (1 .. $proc) {
    is $output{$i}, 1;
    $i++;
  }
};

subtest test_2 => sub {
  my $q = queue;
  $q->pool->maximum_processes(2);
  $q->queue->maximum_processes(800);

  my $proc = 10;
  my $fired;

  my $i = 1;
  for (1 .. $proc) {
    $q->add(process(sub { shift; return shift() })->args($i));
    $i++;
  }

  my %output;
  $q->once(
    stop => sub {
      $fired++;
      $output{shift->return_status}++;
    });
  is $q->queue->size,             $proc - $q->pool->maximum_processes;
  is $q->pool->size,              2;
  is $q->pool->maximum_processes, 2;
  $q->consume;
  is $fired, $proc;
  is $q->queue->size, 0;
  is $q->pool->size,  0;

  $i = 1;
  for (1 .. $proc) {
    is $output{$i}, 1;
    $i++;
  }
};

subtest atomic_queues => sub {
  my $q = queue;
  $q->pool->maximum_processes(1);
  $q->queue->maximum_processes(800);

  my $proc = 10;
  my $fired;

  my $i = 1;
  for (1 .. $proc) {
    $q->add(process(sub { shift; return shift() })->args($i));
    $i++;
  }

  my %output;
  $q->once(
    stop => sub {
      $fired++;
      $output{shift->return_status}++;
    });
  is $q->queue->size,             $proc - $q->pool->maximum_processes;
  is $q->pool->size,              1;
  is $q->pool->maximum_processes, 1;
  $q->consume;
  is $fired, $proc;
  is $q->queue->size, 0;
  is $q->pool->size,  0;

  $i = 1;
  for (1 .. $proc) {
    is $output{$i}, 1;
    $i++;
  }
};

subtest test_3 => sub {
  my $q = queue();
  $q->pool->maximum_processes(4);
  $q->queue->maximum_processes(100000);
  my $proc = 10;
  my $fired;
  my %output;
  my $i = 1;

# Started as long as resources allows (maximum_processes of the main pool)
# That requires then to subscribe for each process event's separately (manually)
  for (1 .. $proc) {
    my $p = process(sub { shift; return shift() + 42 })->args($i);
    $p->once(
      stop => sub {
        $fired++;
        $output{shift->return_status}++;
      });
    $q->add($p);
    $i++;
  }

  is $q->pool->maximum_processes, 4;
  $q->consume;
  is $q->queue->size, 0;
  is $q->pool->size,  0;
  is $fired, $proc;
  $i = 1;
  for (1 .. $proc) {
    is $output{$i + 42}, 1 or diag explain \%output;
    $i++;
  }
};

is(Mojo::IOLoop::ReadWriteProcess::Session->singleton->all->size,         40);
is(Mojo::IOLoop::ReadWriteProcess::Session->singleton->all_orphans->size, 0);

done_testing;
