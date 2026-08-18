# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

owner = User.find_or_initialize_by(email_address: "owner@angar.local")
owner.assign_attributes(
  name: "Власник",
  password: "password123",
  role: :owner,
  payroll_percent: 0,
  active: true
)
owner.save!

puts "Owner account ready: #{owner.email_address} / password123"

viktor = User.find_or_initialize_by(email_address: "vityok.kostiuk@gmail.com")
viktor.assign_attributes(
  name: "Viktor",
  password: "vityok.kostiuk@gmail.com",
  role: :admin,
  payroll_percent: 35,
  active: true
)
viktor.save!

puts "Admin account ready: #{viktor.email_address}"

SERVICE_CATEGORIES = %w[ Загальне\ ТО Трансмісія Гальма Колеса Рульове\ управління Підвіска Палки\ і\ аксесуари ]
PART_CATEGORIES = [
  "Ланцюги", "Касети / тріщітки", "Троси / рубашки", "Гальмівні колодки",
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

MECHANICS = [
  [ "Андрій", "andrii@angar.local", 35 ],
  [ "Сергій", "sergii@angar.local", 35 ],
  [ "Женя", "zhenya@angar.local", 0 ]
]

mechanics = MECHANICS.to_h do |name, email, payroll_percent|
  user = User.find_or_initialize_by(email_address: email)
  user.assign_attributes(name: name, password: "password123", role: :mechanic, payroll_percent: payroll_percent, active: true)
  user.save!
  [ name, user ]
end

puts "Mechanics ready: #{mechanics.keys.join(', ')}"

# Orders are built the same way the intake screen builds them — through
# Orders::Create — and lines are added the same way the order card does, so
# totals are always computed by the model callbacks, never hand-set here.
def seed_order(client_name:, client_phone:, bike_name:, accepted_by:, mechanic:, problem:,
                comment: nil, status:, accepted_days_ago: 0, works: [], parts: [])
  client = Client.find_or_create_by!(phone: Client.normalize_phone(client_phone)) { |c| c.name = client_name }
  bike = client.bikes.find_or_create_by!(name: bike_name)

  existing = Order.find_by(client: client, bike: bike, problem: problem)
  return existing if existing

  order = Orders::Create.call(
    accepted_by: accepted_by, client_id: client.id, bike_id: bike.id, problem: problem, comment: comment
  )
  raise "seed order failed: #{order.errors.full_messages.join(', ')}" unless order.persisted?

  order.update!(mechanic: mechanic, status: status, accepted_at: accepted_days_ago.days.ago)

  works.each do |w|
    if w[:service]
      order.order_works.create!(service: Service.find_by!(name: w[:service]), quantity: w[:qty] || 1)
    else
      order.order_works.create!(name: w[:name], quantity: w[:qty] || 1, price: w[:price])
    end
  end

  parts.each do |p|
    if p[:part]
      order.order_parts.create!(part: Part.find_by!(name: p[:part]), quantity: p[:qty] || 1)
    else
      order.order_parts.create!(name: p[:name], quantity: p[:qty] || 1, price: p[:price])
    end
  end

  order
end

owner_user = owner
andrii, sergii, zhenya = mechanics.values_at("Андрій", "Сергій", "Женя")

# The mockup-04 order (docs/mockups/04-order-card.jpeg): #024, Trek Marlin 7,
# 850 грн works + 1070 грн parts = 1920 грн.
seed_order(
  client_name: "Іван Петренко", client_phone: "0971234567", bike_name: "Trek Marlin 7",
  accepted_by: zhenya, mechanic: andrii, status: :in_progress, accepted_days_ago: 0,
  problem: "Погано перемикає передачі", comment: "Клієнт просить погодити вартість перед заміною деталей",
  works: [ { name: "ТО трансмісії", price: 600 }, { service: "Заміна ланцюга" } ],
  parts: [ { part: "Ланцюг КМС X10" }, { part: "Трос перемикача Shimano" } ]
)

seed_order(
  client_name: "Олег Савчук", client_phone: "0633456789", bike_name: "Cube Aim",
  accepted_by: sergii, mechanic: sergii, status: :waiting_approval, accepted_days_ago: 1,
  problem: "Люфт у каретці", comment: "Погодити заміну каретки"
)

seed_order(
  client_name: "Петро Іваненко", client_phone: "0504567890", bike_name: "Cannondale Topstone",
  accepted_by: andrii, mechanic: andrii, status: :waiting_approval, accepted_days_ago: 2,
  problem: "Погодити заміну касети та ланцюга",
  works: [ { service: "Заміна ланцюга" } ], parts: [ { part: "Ланцюг КМС X10" } ]
)

seed_order(
  client_name: "Марія Коваль", client_phone: "0672345678", bike_name: "Giant Revolt",
  accepted_by: andrii, mechanic: sergii, status: :in_progress, accepted_days_ago: 1,
  problem: "Скрипить каретка",
  works: [ { name: "Перебірка каретки", price: 400 } ], parts: [ { part: "Каретка Shimano BB-RS500" } ]
)

seed_order(
  client_name: "Петро Іваненко", client_phone: "0504567890", bike_name: "Specialized Rockhopper",
  accepted_by: zhenya, mechanic: andrii, status: :waiting_parts, accepted_days_ago: 6,
  problem: "Базове ТО перед сезоном",
  works: [ { service: "Базове ТО велосипеда" } ], parts: [ { part: "Камера 700x35/43", qty: 2 } ]
)

seed_order(
  client_name: "Марія Коваль", client_phone: "0672345678", bike_name: "Liv Rove 1",
  accepted_by: zhenya, mechanic: zhenya, status: :waiting_pickup, accepted_days_ago: 3,
  problem: "Налаштувати перемикачі, встановити багажник",
  works: [ { service: "Налаштування заднього перемикача" }, { service: "Встановлення багажника" } ]
)

seed_order(
  client_name: "Роман Бондар", client_phone: "0509876543", bike_name: "Trek Marlin 7",
  accepted_by: owner_user, mechanic: sergii, status: :intake, accepted_days_ago: 0,
  problem: "Прокачати гальма"
)

seed_order(
  client_name: "Оксана Лисенко", client_phone: "0638765432", bike_name: "Cube Aim",
  accepted_by: sergii, mechanic: andrii, status: :in_progress, accepted_days_ago: 4,
  problem: "Перебрати вилку",
  works: [ { service: "Перебірка вилки" } ]
)

seed_order(
  client_name: "Дмитро Мельник", client_phone: "0677654321", bike_name: "Giant Revolt",
  accepted_by: zhenya, mechanic: zhenya, status: :in_progress, accepted_days_ago: 2,
  problem: "Заміна покришок",
  parts: [ { part: "Покришка Schwalbe Marathon 700x32", qty: 2 } ]
)

seed_order(
  client_name: "Роман Бондар", client_phone: "0509876543", bike_name: "Cannondale Topstone",
  accepted_by: owner_user, mechanic: sergii, status: :waiting_pickup, accepted_days_ago: 5,
  problem: "Центрування переднього колеса",
  works: [ { service: "Центрування колеса" } ]
)

puts "Orders ready: #{Order.count}"
