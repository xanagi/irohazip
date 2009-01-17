#
#  AppController.rb
#  IrohaZip
#
#  Created by Tomonori Kusanagi on 09/01/13.
#  Copyright (c) 2009 Banana Systems. All rights reserved.
#

require 'osx/cocoa'

class AppController < OSX::NSObject
  ib_outlet :window, :button, :archiver, :progress_window, :progress_button
  
  # nib からロード時に行う処理.
  def awakeFromNib
    @state = :initialized
  end
  
  # アプリケーションからのdelegateにより、ファイルを開く.
  # application:openFile: の実装.
  def application_openFile(app, filename)
    unless @archiver.filename
      # Cocoa Binding を使用するため、setValue_forKey_を使う.
      @archiver.setValue_forKey_(filename.to_s, 'filename')
      @state = :initialized
      @window.makeKeyAndOrderFront(self)
    end
    false
  end
  
  # アプリケーション起動完了時の処理.
  # ファイルがセットされていればボタンを有効化する.
  def applicationDidFinishLaunching(notification)
    check_gems
    @button.setEnabled(true) if @archiver.filename
    @window.makeKeyAndOrderFront(self)
  end
  
  # 最後のウィンドウが閉じられたらアプリケーションを終了.
  def applicationShouldTerminateAfterLastWindowClosed(sender)
    return true
  end
  
  # 終了時の後始末.
  def applicationWillTerminate(sender)
    @archiver.cleanup_tempfile
  end
  
  # 設定ウィンドウのボタンが押されたときの処理.
  def button_pressed
    case(@state)
	  when :initialized
	    self.set_state :archiving
	    archive
    end
  end
  ib_action :button_pressed
  
  # 進行状況ウィンドウのボタンが押されたときの処理.
  def progress_button_pressed
    case(@state)
    when :archiving
      # 中断して終了.
      finish_and_exit
	  when :finished
	    finish_and_exit
    end
  end
  ib_action :progress_button_pressed
  
  # 状態をセット.
  def set_state(state)
    case(state)
    when :archiving
      @state = :archiving
      @progress_window.makeKeyAndOrderFront(self)
      @window.close
    when :finished
      @state = :finished
      @progress_button.setTitle(OSX::NSLocalizedString('Done'))
      @progress_button.setEnabled(true)
    end
  end
  
  #========== 以下 private ==========
  private
  
  # 必要な gem がインストールされているかどうかチェック.
  def check_gems
    begin
      require 'rubygems'
      gem 'zipruby', '~> 0.2.9'
    rescue Gem::LoadError => e
      alert = OSX::NSAlert.alloc.init
      alert.addButtonWithTitle('OK')
      alert.setMessageText(OSX::NSLocalizedString('zipruby ( >0.2.9 ) must be installed.'))
      alert.setInformativeText(OSX::NSLocalizedString("Install zipruby by executing '$sudo gem install zipruby' from Terminal.app."))
      alert.setAlertStyle(OSX::NSWarningAlertStyle)
      if alert.runModal == OSX::NSAlertFirstButtonReturn
        @window.close
      end
    end
  end

  # 圧縮実行.
  def archive
    t = Thread.new(self, @archiver, @window) do |controller, arhiver, window|
      begin
        arhiver.create_zip
        controller.set_state :finished
      rescue => e
        alert = OSX::NSAlert.alloc.init
        alert.addButtonWithTitle('OK')
        alert.setMessageText(OSX::NSLocalizedString('Compression failed.'))
        alert.setInformativeText(e.message)
        alert.setAlertStyle(OSX::NSWarningAlertStyle)
        if alert.runModal == OSX::NSAlertFirstButtonReturn
          @progress_window.close
        end
      end
    end
  end
  
  # 終了処理.
  def finish_and_exit
    @progress_window.close
  end
end
