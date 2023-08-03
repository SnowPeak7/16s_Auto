from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
import os



def acclist_by_prj(prj, out_dir):
    driver_path = "/home/ljr/snap/chromedriver"
    out_path = os.path.join(out_dir, prj)
    service = Service(driver_path)
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_experimental_option("prefs", {
        "download.default_directory": out_path,
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "safebrowsing.enabled": True
    })
    driver = webdriver.Chrome(service=service, options=options)
    try:
        driver.get(f"https://www.ncbi.nlm.nih.gov/Traces/study/?acc={prj}")

        wait = WebDriverWait(driver, 60)
        download_button = wait.until(EC.visibility_of_element_located((By.ID, "t-rit-all")))
        download_button.click()

        download_button = wait.until(EC.visibility_of_element_located((By.ID, "t-acclist-all")))
        download_button.click()

        time.sleep(3)

        file_path = os.path.join(out_path, "SRR_Acc_List.txt")
        max_retries = 15
        retry_count = 0

        while retry_count < max_retries:
            if not os.path.exists(file_path):
                retry_count += 1
                time.sleep(2)
            else:
                srr_acc_list = get_srr_by_txt(file_path)
                print(f'任务：{prj} 共 {len(srr_acc_list)} 项待下载')
                return out_path
        print(f"查找内容失败")
        exit()
    except Exception as e:
        print(f"查找内容失败 : {e}")
        exit()
    finally:
        driver.quit()

if __name__ == '__main__':


    sras = "PRJNA252404"

    out_dir = '.'

    acclist_by_prj(sras, out_dir)
    print('所有任务全部完成')