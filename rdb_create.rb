require "json"
require "selenium-webdriver"
require "rspec"
require "rubyXL"
include RSpec::Expectations

username = 
password =
max = 21
vm_name = "selenium"
time_limit = 30 # mins
schema = %w(flag 作成開始日時 処理 結果 ゾーン 完了時刻 処理時間 実施者)

describe "RdbCreate" do
  before(:all) do
    
    @conf = {
             name: vm_name,
             zone: "henry",
             network: "henry-network1",
             type: "light.S1( 1CPU / 1GB RAM )",
             size: "3",
             group: "light.S1default_VJrMf_ZGAWg",
             disk_size: "5"
            }

    @result = {flag: "",
               start_time: "",
               process: "3ノード作成",
               status:  "",
               zone: @conf[:zone],
               end_time: "dummy",
               process_time: "",
               author: "杉本"
              }

    @workbook = RubyXL::Workbook.new
    count = 0
    @worksheet = @workbook[0]
    schema.each do |column|
      @worksheet.add_cell(0, count, column)
      count += 1
    end
  end

  before(:each) do
    @driver = Selenium::WebDriver.for :firefox
    @base_url = "https://account.idcfcloud.com/"
    @accept_next_alert = true
    @driver.manage.timeouts.implicit_wait = 1 * 60
    @verification_errors = []
    @driver.get(@base_url + "auth/login?service=https://console.idcfcloud.com/")
    @driver.find_element(:id, "username").clear
    @driver.find_element(:id, "username").send_keys username
    @driver.find_element(:id, "password").clear
    @driver.find_element(:id, "password").send_keys password
    @driver.find_element(:name, "submit").click
    @driver.find_element(:css, "span.text").click
    @driver.find_element(:xpath, "//li[@id='select-service']/table/tbody/tr[2]/td[2]/a/div").click
  end
  
  after(:each) do
    sleep 3
    @driver.quit
    expect(@verification_errors).to eq([])
  end

  after(:all) do
    keys = @result.keys
    p keys
    count = 0
    keys.each do |key|
      p @result[key]
      @worksheet.add_cell(1, count, @result[key])
      count += 1
    end
    @workbook.write("result.xlsx")
  end

 it "create" do
    expect(@driver.title).to eq("RDB")
    @driver.find_element(:link, "DBサーバー作成").click
    while @driver.find_element(:id, "instanceName").attribute("value") != "defaultInstance"
      sleep 5
    end
    print @driver.find_element(:id, "instanceName").attribute("value")
    @driver.find_element(:id, "instanceName").clear
    @driver.find_element(:id, "instanceName").send_keys "selenium-001"
    Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, "availabilityZone")).select_by(:text, "henry")
    Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, "network")).select_by(:text, "henry-network1")
    Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, "instanceType")).select_by(:text, "light.S1( 1CPU / 1GB RAM )")
    @driver.find_element(:link, "次へ").click
    Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, "parameterGroup")).select_by(:text, "light.S1default_VJrMf_ZGAWg")
    @driver.find_element(:id, "storageSize").clear
    @driver.find_element(:id, "storageSize").send_keys "5"
    @driver.find_element(:link, "申込む").click

    @driver.find_element(:xpath, "//div[@id='main-content']/div/div/div/div/div[3]/button").click
#    @driver.find_element(:css, "css=div.modal-footer > button.btn.btn-primary").click
    @driver.find_element(:xpath, "//button[@type='button']").click
#    @driver.find_element(:link, "戻る).click
  end

  it "find first sentence" do
    # 本当はfind_element(:link, VMNAME)をしなければならないが要素が不確定なため調査後に実装
    @driver.find_element(:link, 'イベント').click
    line = 2 # 最初の行
    # ここだけtimeoutを短めに設定
    @driver.manage.timeouts.implicit_wait = 30
    found_task_start = false
    sentence = ""
    while !found_task_start
      p "in roop"
      begin
        sentence = @driver.find_element(:xpath, "//*[@id='datatable2']/tbody/tr[#{line}]/td[3]").text
        found_task_start = true
        #本当は必要
        #でも30秒で21行が埋まらないかぎり要らないので取り敢えず未実装
        p sentence
        #if sentence == "Create instance job started" then
        #else
        # さらにロードするボタンを押す
        # end
        @result.store(:start_time, @driver.find_element(:css, "#datatable2 > tbody > tr:nth-child(#{line}) > td.center.ng-binding").text)
      rescue
        # timeout したら再読み込み
        sleep 5
        @driver.find_element(:xpath, "//div[@id='tab2']/div/button[2]").click
      end
    end
    p "end"
  end




  it "find finished sentence" do
    p @driver.find_element(:xpath, '//div[2]/div/div/table/tbody/tr/td').text
    @driver.find_element(:link, 'イベント').click
    found_task_end = false
    timeout_count = 0
    sentence = ""
    before_sentence = ""
    first_found_time = 0.0
    line = 2
    max_line = 21 # さらにロードするを押さないかぎり21行目が最大ということを確認
    while !found_task_end
      begin
        sentence = @driver.find_element(:xpath, "//*[@id='datatable2']/tbody/tr[#{line}]/td[3]").text
        p sentence
        if sentence == "All Tasks for current job completed successfully" then
          found_task_end = true
           # get time code
          @result.store(:end_time, @driver.find_element(:css, "#datatable2 > tbody > tr:nth-child(#{line}) > td.center.ng-binding").text)
          @result.store(:status  , "成功")
        else
          # found but not match
          if sentence != before_sentence then
            first_found_time = Time.now
            before_sentence = sentence
            if line != max_line then
              line +=1
            end
            # 再読み込みを押す
            sleep 10
            @driver.find_element(:xpath, "//div[@id='tab2']/div/button[2]").click
          else
            # 同じ文が出続けていたら、処理が止まっているものとみなす
            stay_time = (Time.now - first_fount_time).divmod(24*60*60)[1].divmod(60*60)[1].divmod(60)
            # time_limit超えたら終了
            if stay_time > time_limit then
              @result.store(:end_time, @driver.find_element(:css, "#datatable2 > tbody > tr:nth-child(#{line}) > td.center.ng-binding").text)
              @result.store(:status, "失敗")
              break
            else
              sleep 60
              @driver.find_element(:xpath, "//div[@id='tab2']/div/button[2]").click
            end
          end
        end
      rescue
        #if timeout_count > (time_limit * 60)/ @driver.manage.timeouts.implicit_wait then
        if timeout_count >  30  then
          p "見つからないよ"
          @result.store(:end_time, @driver.find_element(:css, "#datatable2 > tbody > tr:nth-child(#{line}) > td.center.ng-binding").text)
          @result.store(:status, "失敗")
          break
        else
          @driver.find_element(:xpath, "//div[@id='tab2']/div/button[2]").click
        end
      end
    end
  end
end
