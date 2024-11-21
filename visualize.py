import pandas as pd
import matplotlib.pyplot as plt

# Загрузка данных из файла CSV
data = pd.read_csv('rate_example.csv',sep=',')
data_scw = pd.read_csv('rate_side_bend.csv',sep=',')
# Создание фигуры и осей для нескольких графиков

plt.figure()
plt.semilogy(data_scw['D'], data_scw['R_dl'],'--', marker='o', color='r', label='БЧ')
plt.xlabel('Distance km')
plt.ylabel('Rate')
plt.legend()
plt.show()

plt.figure()
plt.semilogy(data['D'], data['R_dl'], marker='o', color='b', label='НЕ БЧ')
plt.semilogy(data_scw['D'], data_scw['R_dl'],'--', marker='o', color='r', label='БЧ')
plt.ylabel('R_dl')
plt.legend()
plt.grid()
plt.tight_layout()
plt.show()

fig, axes = plt.subplots(3, 1, figsize=(10, 15), sharex=True)
d = data.head
# Построение зависимости amp от D
# axes[0].plot(data['D'], data['amp'],  marker='o', color='b', label='НЕ БЧ')
axes[0].plot(data_scw['D'], data_scw['amp'], '--',marker='o', color='r', label='БЧ')
axes[0].set_ylabel('amp')
axes[0].set_title('Зависимости от D')
axes[0].legend()
axes[0].grid()

# Построение зависимости R_dl от D
# axes[1].plot(data['D'], data['R_dl'], marker='o', color='b', label='НЕ БЧ')
axes[1].plot(data_scw['D'], data_scw['R_dl'],'--', marker='o', color='r', label='БЧ')
axes[1].set_yscale('log')
axes[1].set_ylabel('R_dl')
axes[1].legend()
axes[1].grid()

# Построение зависимости deltaEC от D
# axes[2].plot(data['D'], data['deltaEC'], marker='o', color='b', label='НЕ БЧ')
axes[2].plot(data_scw['D'], data_scw['deltaEC'],'--', marker='o', color='r', label='БЧ')
axes[2].set_xlabel('D')
axes[2].set_ylabel('deltaEC')
axes[2].legend()
axes[2].grid()

# Отображение графиков
plt.tight_layout()
plt.show()

