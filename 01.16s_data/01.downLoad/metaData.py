from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
import os
import time

def download_metadata(prj, out_dir, chrome_path, driver_path):
    out_path = os.path.join(out_dir, prj)
    service = Service(driver_path)
    options = Options()
    options.binary_location = chrome_path  # 指定Chrome的路径
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
        wait = WebDriverWait(driver, 30)
        download_button = wait.until(EC.visibility_of_element_located((By.ID, "t-rit-all")))
        download_button.click()
        time.sleep(3)
    except Exception as e:
        print(f"下载metadata失败 : {e}")
        exit()
    finally:
        driver.quit()

if __name__ == '__main__':
    prj = "PRJNA252404"
    out_dir = '.'
    chrome_path = "/home/ljr/snap/116/chrome-linux64/chrome"
    driver_path = "/home/ljr/snap/116/chromedriver-linux64/chromedriver"

    download_metadata(prj, out_dir, chrome_path, driver_path)
    print('任务完成')