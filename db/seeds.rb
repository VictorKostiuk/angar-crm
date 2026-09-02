owner = User.find_or_initialize_by(email_address: "angarvelokafe@gmail.com")
owner.assign_attributes(
  name: "Женя",
  password: "angarvelokafe@gmail.com",
  role: :owner,
  payroll_percent: 0,
  active: true
)
owner.save!

puts "Owner account ready: #{owner.email_address} / #{owner.password}"

viktor = User.find_or_initialize_by(email_address: "vityok.kostiuk@gmail.com")
viktor.assign_attributes(
  name: "Viktor",
  password: "vityok.kostiuk@gmail.com",
  role: :owner,
  payroll_percent: 35,
  active: true
)
viktor.save!

puts "Owner account ready: #{viktor.email_address} / #{viktor.password}"

SERVICE_CATEGORIES = %w[ Загальне\ ТО Трансмісія Гальма Колеса Рульове\ управління Підвіска Палки\ і\ аксесуари ]
PART_CATEGORIES = [
  "Ланцюги", "Касети / тріскалки", "Троси / рубашки", "Гальмівні колодки",
  "Камери", "Покришки", "Мастила / герметики", "Підшипники", "Каретки", "Інше"
]

service_categories = SERVICE_CATEGORIES.each_with_index.to_h do |name, i|
  [ name, Category.find_or_create_by!(kind: :service, name: name) { |c| c.position = i } ]
end

part_categories = PART_CATEGORIES.each_with_index.to_h do |name, i|
  [ name, Category.find_or_create_by!(kind: :part, name: name) { |c| c.position = i } ]
end

SERVICES = [
  [ "Повне ТО велосипеда", "Загальне ТО", 1800 ],
  [ "Базове ТО велосипеда", "Загальне ТО", 900 ],
  [ "Заміна ланцюга", "Трансмісія", 250 ],
  [ "Налаштування заднього перемикача", "Трансмісія", 300 ],
  [ "Прокачка гальма", "Гальма", 450 ],
  [ "Заміна гальмівних колодок", "Гальма", 250 ],
  [ "Центрування колеса", "Колеса", 350 ],
  [ "Перебірка втулки", "Колеса", 500 ],
  [ "Налаштування рульової", "Рульове управління", 250 ],
  [ "Перебірка вилки", "Підвіска", 1200 ],
  [ "Встановлення багажника", "Палки і аксесуари", 300 ],
  [ "Заміна обмотки керма", "Палки і аксесуари", 250 ]
]

SERVICES.each_with_index do |(name, category_name, price), i|
  service = Service.find_or_initialize_by(name: name)
  service.assign_attributes(category: service_categories.fetch(category_name), base_price: price, position: i)
  service.save!
end

PARTS = [
  [ "Ланцюг КМС X10", "Ланцюги", 950 ],
  [ "Трос перемикача Shimano", "Троси / рубашки", 120 ],
  [ "Трос гальма Shimano", "Троси / рубашки", 120 ],
  [ "Камера 700x35/43", "Камери", 180 ],
  [ "Колодки Shimano B01S", "Гальмівні колодки", 350 ],
  [ "Покришка Schwalbe Marathon 700x32", "Покришки", 1450 ],
  [ "Герметик для безкамерних шин", "Мастила / герметики", 350 ],
  [ "Каретка Shimano BB-RS500", "Каретки", 650 ]
]

PARTS.each_with_index do |(name, category_name, price), i|
  part = Part.find_or_initialize_by(name: name)
  part.assign_attributes(category: part_categories.fetch(category_name), base_price: price, position: i)
  part.save!
end

puts "Catalogs ready: #{Service.count} services, #{Part.count} parts, #{Category.count} categories"
