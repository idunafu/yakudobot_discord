import pixie, httpclient, times

# calc yakudo score
# 1. apply laplacian filter
# 2. calculate image mean and variance
# 3. calculate yakudo score based on mean and variance

proc applyLaplacianFilter(image: Image): Image =
  var resultimg = newImage(image.width, image.height)
  
  # カーネルサイズ1の場合の3x3マトリックス
  const kernel = [
    [0, 1, 0],
    [1, -4, 1],
    [0, 1, 0]
  ]
  
  for y in 1..image.height-2:
    for x in 1..image.width-2:
      var r, g, b: int
      
      for ky in 0..2:
        for kx in 0..2:
          let pixel = image[x + kx - 1, y + ky - 1]
          r += pixel.r.int * kernel[ky][kx]
          g += pixel.g.int * kernel[ky][kx]
          b += pixel.b.int * kernel[ky][kx]
      
      setColor(resultimg, x, y, rgba(clamp(abs(r), 0, 255).uint8, clamp(abs(g), 0, 255).uint8, clamp(abs(b), 0, 255).uint8, 255).color)
  
  return resultimg

proc getImageFromUrl*(url: string): Image =
  #debug
  echo "getImageFromUrl: ", url

  let client = newHttpClient()
  defer: client.close()
  try:
    let response = client.get(url)
    if response.code == Http200:
      let image = decodeImage(response.body)
      return image
    else:
      echo "画像の取得に失敗しました: HTTP ", response.code
      return nil
  except Exception as e:
    echo "画像の取得中にエラーが発生しました: ", e.msg
    return nil
    

proc calcYakudoScore*(image: Image): float64 =
  let filtered = applyLaplacianFilter(image)
  #RGB各チャンネルの値を合計し、画像の全ピクセル数(w*h*3)で割ることで平均値を算出
  var sum: int
  for y in 0..<filtered.height:
    for x in 0..<filtered.width:
      let pixel = filtered[x, y]
      sum += pixel.r.int + pixel.g.int + pixel.b.int
  let mean: float64 = sum.float64 / (filtered.width * filtered.height * 3).float64

  #RGB各チャンネルの値から平均値を引いた値を2乗し、画像の全ピクセル数(w*h*3)で割ることで分散を算出
  var variance: float64
  for y in 0..<filtered.height:
    for x in 0..<filtered.width:
      let pixel = filtered[x, y]
      variance += pow(pixel.r.float64/255.0 - mean, 2) + pow(pixel.g.float64/255.0 - mean, 2) + pow(pixel.b.float64/255.0 - mean, 2)
  
  variance /= (filtered.width * filtered.height * 3).float64

  result = 5000.0 / variance

proc jstInfo(time: Time): ZonedTime =
  ZonedTime(utcOffset: -32400, isDst: false, time: time)

proc jstTimeStr*(time: Time): string =
  let jst = newTimezone("Asia/Tokyo", jstInfo, jstInfo)
  return time.inZone(jst).format("yyyy-MM-dd")

