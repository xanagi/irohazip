#
#  WinJFriendlyArchiver.rb
#
#  Created by Tomonori Kusanagi on 08/12/12.
#  Copyright (c) 2008 Banana Systems, Inc. All rights reserved.
#
require 'osx/cocoa'
require 'rubygems'
require 'zipruby'
require 'nkf'
require 'tmpdir'

class WinJFriendlyArchiver < OSX::NSObject
  ib_outlet :button
  attr_accessor :do_encrypt, :password, :current_progress, :current_file
  attr_reader :filename
  
  # 圧縮対象ファイルをセット.
  def filename=(filename)
    begin
      filename = (filename.is_a? OSX::NSURL) ? filename.path : filename
      self.check_file(filename)
      @filename = filename
      @abs_path = File.expand_path @filename
      @dirname = File.dirname @abs_path
      @basename = File.basename @abs_path, ".*"
    rescue => e
      alert = OSX::NSAlert.alloc.init
      alert.addButtonWithTitle('OK')
      alert.setMessageText(e.message)
      alert.setAlertStyle(OSX::NSWarningAlertStyle)
      if alert.runModal == OSX::NSAlertFirstButtonReturn
        self.setValue_forKey_(nil, 'filename')
      end
    end
  end
  
  # ファイルをチェック.
  def check_file(filename)
    @button.setEnabled(false)
    raise "#{filename}#{OSX::NSLocalizedString(' is not found.')}" unless File.exist? filename
    abs_path = File.expand_path filename
    raise OSX::NSLocalizedString("Invalid file.") if !(FileTest.directory? abs_path) && !(FileTest.file? abs_path)
    @button.setEnabled(true)
    true
  end
  
  # zip ファイルを作成.
  def create_zip
    filename = zip_filename
    zip_path = File.expand_path "~/Desktop/#{filename}"
    raise "#{filename}#{OSX::NSLocalizedString(' already exists.')}" if File.exist? zip_path

    files = []
    if FileTest.directory? @abs_path
      # 下位にあるファイルの一覧を取得.
      subpath = @abs_path + File::SEPARATOR + "**" + File::SEPARATOR + "*"
      files += Dir.glob(subpath).select{|f| FileTest.file? f}
    elsif FileTest.file? @abs_path
      files << @abs_path
    end

    #@tmp_zip_path = "#{Dir.tmpdir}/#{zip_path}.tmp"
    @tmp_zip_path = "#{zip_path}.tmp"
    cleanup_tempfile
    
    # zip 圧縮.
    compress_part_parcentage = (@do_encrypt && @password) ? 80.0 : 90.0
    Zip::Archive.open(@tmp_zip_path, Zip::CREATE) do |ar|
      files = files.select{|f| f != '.DS_Store'} # .DS_Store を除くファイル.
      prev = -1
      files.each_with_index do |file, i|
        # zip中のエントリ名. ベースディレクトリからの相対パスにして、Shift_JISに変換.
        file_path = file.sub(/^#{@dirname}\//, '')
        name = NKF::nkf("-Ws", file_path)
        bin = File.open(file, "rb").read
        ar.add_buffer(name, bin)
        current = (compress_part_parcentage * (i + 1) / files.size).to_i # 整数%にする.
        if current > prev
          self.setValue_forKey_(current * 1.0, 'current_progress')
          self.setValue_forKey_(file_path, 'current_file')
          prev = current
          sleep(0.01)
        end
      end
      self.setValue_forKey_(OSX::NSLocalizedString('Generating file..'), 'current_file')
    end

    # 暗号化.
    if @do_encrypt && @password
      self.setValue_forKey_(90.0, 'current_progress')
      self.setValue_forKey_(OSX::NSLocalizedString('Encrypting..'), 'current_file')
      Zip::Archive.encrypt(@tmp_zip_path, @password.to_s)
    end
    
    # 完了処理.
    FileUtils.cp(@tmp_zip_path, zip_path)
    self.setValue_forKey_(100.0, 'current_progress')
    self.setValue_forKey_(OSX::NSLocalizedString('Done'), 'current_file')
    true
  end
  
  # 一時ファイルを削除.
  def cleanup_tempfile
    if @tmp_zip_path && FileTest.exists?(@tmp_zip_path)
      FileUtils.rm(@tmp_zip_path)
    end
  end
  
  # 出力zipファイル名を取得.
  # xxx.zip というファイルが既にあれば、xxxの後に数字をつけてファイル名を作成する.
  def zip_filename
    filename = "#{@basename}.zip"
    existing_zips = Dir.glob(File.expand_path("~/Desktop/#{@basename}*.zip")).collect{|f| File.basename f}
    i = 1
    while existing_zips.find{|f| f == filename}
      filename = "#{@basename} #{i}.zip"
      i += 1
    end
    filename
  end
end
