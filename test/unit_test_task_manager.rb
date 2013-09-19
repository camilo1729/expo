#!/usr/bin/ruby -w

[ '../lib', 'lib' ].each { |d| $:.unshift(d) if File::directory?(d) }

require 'rubygems'
require 'task_manager'
require 'tasks'
require 'test/unit'
require 'yaml'

class ResourceSetTest < Test::Unit::TestCase

  def test_taskcreation
    task_1 = Task::new :task_1 do
      puts "Task 1 "
    end 
    assert(task_1.name == :task_1)
  end

  def test_one_task_schedule
    task_1 = Task::new :task_1 do
      puts "Task 1 "
    end

    t = TaskManager::new([task_1])
    t.schedule_new_task
    sleep 2 ## We have to wait a little to schedule the task
    assert(t.finish_tasks? == true)
  end

  def test_simple_dependency
    
    task_1 = Task::new :task_1 do
      puts "Task 1 "
    end 

    task_2 = Task::new :task_2 do
      puts "Task 2"
    end

    task_3 = Task::new :task_3, :depends => [:task_1] do
      puts "Task 3"
    end

    task_4 = Task::new :task_4, :depends => [:task_2] do
      puts "Task 4"
    end
    t = TaskManager::new([task_1,task_2,task_3,task_4])
    t.schedule_new_task
    sleep 5
    assert(t.finish_tasks? == true)
  end

  def test_dependency_exist

    task_1 = Task::new :task_1 do
      puts "Task 1 "
    end 

    task_2 = Task::new :task_2,:depens => [:task_1] do
      puts "Task 2"
    end

    task_3 = Task::new :task_3, :depends => [:task_32] do
      puts "Task 3"
    end

    t = TaskManager::new([task_1,task_2,task_3])
    t.schedule_new_task
    sleep 10
    assert(t.finish_tasks? == true)
    
  end
   
end
